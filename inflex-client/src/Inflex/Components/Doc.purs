-- |

module Inflex.Components.Doc
  ( component
  ) where

import Control.Monad.State (class MonadState)
import Data.Array (filter)
import Data.Either (Either(..))
import Data.Foldable (maximum)
import Data.Maybe
import Data.Maybe (fromMaybe)
import Data.MediaType
import Data.Symbol (SProxy(..))
import Data.UUID (UUID, genUUIDV4, uuidToString)
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Aff.Class (class MonadAff)
import Effect.Class (class MonadEffect)
import Effect.Class.Console (log, error)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Inflex.Components.Cell as Cell
import Inflex.Rpc (rpcLoadDocument, rpcRefreshDocument)
import Inflex.Schema
import Prelude
import Web.Event.Event (preventDefault, stopPropagation, currentTarget)
import Web.HTML.Event.DataTransfer as DT
import Web.HTML.Event.DragEvent as DE
import Web.UIEvent.MouseEvent as ME

--------------------------------------------------------------------------------
-- Foreign

foreign import getDocumentId :: Effect Int

foreign import dragEventToMouseEvent :: DE.DragEvent -> ME.MouseEvent

--------------------------------------------------------------------------------
-- Types

data Command
  = Initialize
  | UpdateCell UUID {name :: String, code :: String}
  | NewCell
  | DeleteCell UUID
  | DragStart UUID DE.DragEvent
  | OnDragOver DE.DragEvent
  | OnDrop DE.DragEvent

type State = {
    cells :: Array OutputCell
  , dragUUID :: Maybe UUID
 }

type Input = Unit

type Output = Unit

--------------------------------------------------------------------------------
-- Component

component :: forall q. H.Component HH.HTML q Input Output Aff
component =
  H.mkComponent
    { initialState: const {cells: mempty, dragUUID: Nothing}
    , render
    , eval:
        H.mkEval
          H.defaultEval {initialize = pure Initialize, handleAction = eval}
    }

--------------------------------------------------------------------------------
-- Render

render :: forall q state keys m. MonadEffect m =>
   { cells :: Array OutputCell | state }
   -> HH.HTML (H.ComponentSlot HH.HTML ( "Cell" :: H.Slot Cell.Query Cell.Output String | keys) m Command) Command
render state =
  HH.div
    [HP.class_ (HH.ClassName "ide")]
    [ HH.div
        [HP.class_ (HH.ClassName "sidebar")]
        [ HH.button
            [ HP.class_ (HH.ClassName "sidebar-button")
            , HE.onClick (\e -> pure NewCell)
            ]
            [HH.text "New Cell"]
        ]
    , HH.div
        [ HP.class_ (HH.ClassName "canvas")
        , HE.onDragOver (Just <<< OnDragOver)
        , HE.onDrop (Just <<< OnDrop)
        ]
        (map
           (\cell@(OutputCell {uuid}) ->
              HH.slot
                (SProxy :: SProxy "Cell")
                (uuidToString uuid)
                Cell.component
                cell
                (\update ->
                   pure
                     (case update of
                        Cell.CellUpdate update' -> UpdateCell uuid update'
                        Cell.RemoveCell -> DeleteCell uuid
                        Cell.CellDragStart dragEvent -> DragStart uuid dragEvent)))
           (state . cells))
    ]

--------------------------------------------------------------------------------
-- Eval

mediaType = (MediaType "text/plain")


eval :: forall t122 t125 t129 t130 t131 t258.
  MonadEffect t129 => MonadAff t129 => Command
                                       -> H.HalogenM
                                            { cells :: Array OutputCell
                                            , dragUUID :: Maybe UUID
                                            | t258
                                            }
                                            t131
                                            ( "Cell" :: H.Slot Cell.Query t125 String
                                            | t122
                                            )
                                            t130
                                            t129
                                            Unit
eval =
  case _ of
    OnDrop dragEvent -> do
      pure unit
      H.liftEffect (preventDefault (DE.toEvent dragEvent)) -- To prevent navigating to thing?
    DragStart uuid dragEvent -> do
      H.modify_ (\s -> s {dragUUID = Just uuid})
    OnDragOver dragEvent -> do
      H.liftEffect (preventDefault (DE.toEvent dragEvent)) -- To prevent animation?
      muuid <- H.gets (_ . dragUUID)
      case muuid of
        Nothing -> pure unit
        Just uuid -> do
          let x = ME.clientX (dragEventToMouseEvent dragEvent)
              y = ME.clientY (dragEventToMouseEvent dragEvent)
          _ <-
            H.query
              (SProxy :: SProxy "Cell")
              (uuidToString uuid)
              (Cell.SetXY {x, y})
          pure unit
    Initialize -> do
      documentId <- H.liftEffect getDocumentId
      log "Loading document ..."
      result <- rpcLoadDocument (DocumentId documentId)
      case result of
        Left err -> do
          error err -- TODO:Display this to the user properly.
        Right outputDocument -> setOutputDocument outputDocument
    NewCell -> do
      uuid <- H.liftEffect genUUIDV4
      s <- H.get
      let cells' =
            [ InputCell1
                { uuid: uuid
                , name: ""
                , code: ""
                , order:
                    fromMaybe
                      0
                      (maximum
                         (map (\(OutputCell {order}) -> order) (s . cells))) +
                    1
                , version: versionRefl
                }
            ] <>
            map toInputCell (s . cells)
      H.liftEffect (log "New cell, refreshing ...")
      refresh cells'
    UpdateCell uuid cell -> do
      state <- H.get
      H.liftEffect (log "Cell updated, refreshing ...")
      refresh
        (map
           (\original@(InputCell1 {uuid: uuid', order, version}) ->
              if uuid' == uuid
                then InputCell1
                       { uuid
                       , code: cell . code
                       , name: cell . name
                       , order
                       , version
                       }
                else original)
           (map toInputCell (state . cells)))
    DeleteCell uuid -> do
      state <- H.get
      H.liftEffect (log "Cell deleted, refreshing ...")
      documentId <- H.liftEffect getDocumentId
      refresh
        (map
           toInputCell
           (filter
              (\(OutputCell {uuid: uuid'}) -> uuid' /= uuid)
              (state . cells)))

--------------------------------------------------------------------------------
-- API calls

refresh :: forall t60 t74.
  Bind t60 => MonadEffect t60 => MonadAff t60 => MonadState
                                                   { cells :: Array OutputCell
                                                   | t74
                                                   }
                                                   t60
                                                  => Array InputCell1 -> t60 Unit
refresh cells = do
  documentId <- H.liftEffect getDocumentId
  result <-
    rpcRefreshDocument
      (RefreshDocument
         { documentId: DocumentId documentId
         , document: InputDocument1 {cells: cells}
         })
  case result of
    Left err -> do
      error err -- TODO:Display this to the user properly.
    Right outputDocument -> setOutputDocument outputDocument

--------------------------------------------------------------------------------
-- Internal state helpers

setOutputDocument :: forall t11 t14.
  MonadState
    { cells :: Array OutputCell
    | t14
    }
    t11
   => OutputDocument -> t11 Unit
setOutputDocument (OutputDocument {cells}) =
  H.modify_ (\s -> s {cells = cells})

toInputCell :: OutputCell -> InputCell1
toInputCell (OutputCell {uuid, name, code, order}) =
  InputCell1 {uuid, name, code, order, version: versionRefl}
