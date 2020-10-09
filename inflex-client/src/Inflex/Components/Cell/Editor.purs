-- | Recursive editing of parts of a result.

module Inflex.Components.Cell.Editor
  ( Editor(..)
  , EditorAndCode(..)
  , component
  ) where

import Data.Symbol (SProxy(..))
import Data.Array
import Data.Foldable (for_)
import Data.Maybe (Maybe(..))
import Data.String (joinWith, trim)
import Effect.Class (class MonadEffect)
import Effect.Console (log)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Core as Core
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Query.Input as Input
import Halogen.VDom.DOM.Prop (ElemRef(..))
import Inflex.Schema (CellError(..), FillError(..))
import Prelude (Unit, bind, discard, map, pure, unit, (<<<), (<>), (==))
import Web.DOM.Element (Element)
import Web.Event.Event (preventDefault, stopPropagation)
import Web.Event.Internal.Types (Event)
import Web.HTML.HTMLElement (focus, fromElement)
import Web.UIEvent.KeyboardEvent as K
import Web.UIEvent.MouseEvent (toEvent)

--------------------------------------------------------------------------------
-- Component types

type Input = EditorAndCode

type Output = String

data State = State
  { display :: Display
  , editor :: Editor
  , code :: String
  }

data Command
  = SetEditor EditorAndCode
  | StartEditor
  | FinishEditing String
  | PreventDefault Event
                   Command
  | Autoresize
  | NoOp
  | SetInput String
  | InputElementChanged (ElemRef Element)

--------------------------------------------------------------------------------
-- Internal types

data Editor
  = MiscE String
  | ErrorE CellError
  | ArrayE (Array Editor)

data Display
  = DisplayEditor
  | DisplayCode

data EditorAndCode = EditorAndCode
  { editor :: Editor
  , code :: String
  }

type Slots i = (editor :: H.Slot i String Int)

manage :: forall r i. (ElemRef Element -> i) -> HP.IProp r i
manage act = HP.IProp (Core.Ref (Just <<< Input.Action <<< act))

--------------------------------------------------------------------------------
-- Constants

editorRef :: H.RefLabel
editorRef = (H.RefLabel "editor")

--------------------------------------------------------------------------------
-- Component

component :: forall q m. MonadEffect m => H.Component HH.HTML q Input Output m
component =
  H.mkComponent
    { initialState: (\(EditorAndCode{editor, code}) -> State {display: DisplayEditor, editor, code })
    , render
    , eval: H.mkEval H.defaultEval { handleAction = eval, receive = pure <<< SetEditor }
    }

--------------------------------------------------------------------------------
-- Eval

eval :: forall i t45 t48. MonadEffect t45 => Command -> H.HalogenM State t48 (Slots i) String t45 Unit
eval =
  case _ of
    SetInput i -> do
      H.liftEffect (log "Inflex.Editor:eval(SetInput)")
      H.modify_ (\(State st) -> State (st {display = DisplayCode, code = i}))
    InputElementChanged elemRef ->
      case elemRef of
        Created element ->
          case fromElement element of
            Just htmlelement -> H.liftEffect (focus htmlelement)
            Nothing -> pure unit
        Removed _ -> pure unit
    StartEditor -> do
      H.modify_ (\(State st) -> State (st {display = DisplayCode}))
    FinishEditing code -> do
      H.liftEffect (log ("Finish editing with code:" <> code))
      State {display, editor} <- H.get
      _result <- H.raise code
      H.modify_ (\(State st') -> State (st' {display = DisplayEditor}))
    SetEditor (EditorAndCode {editor, code}) ->
      H.put (State {editor, code, display: DisplayEditor})
    Autoresize -> do
      ref <- H.getHTMLElementRef editorRef
      H.liftEffect (for_ ref (\el -> pure unit))
    PreventDefault e c -> do
      H.liftEffect
        (do log "Preventing default and propagation ..."
            preventDefault e
            stopPropagation e
            log "Triggering")
      eval c
    NoOp -> pure unit

--------------------------------------------------------------------------------
-- Render

render :: forall i a. MonadEffect a => State -> HH.HTML (H.ComponentSlot HH.HTML (Slots i) a Command) Command
render (State {display, code, editor}) =
  case display of
    DisplayCode -> wrapper renderControl
    DisplayEditor ->
      if trim code == ""
        then wrapper (renderControl)
        else wrapper (renderEditor editor)
  where
    renderControl =
      [ HH.input
          [ HP.value code
          , HP.class_ (HH.ClassName "form-control")
          , manage InputElementChanged
          , HE.onKeyUp
              (\k ->
                 case K.code k of
                   "Enter" -> Just (FinishEditing code)
                   _code -> Just Autoresize)
          , HE.onValueChange (\i -> pure (SetInput i))
          , HE.onClick (\e -> pure (PreventDefault (toEvent e) NoOp))
          ]
      ]
    wrapper inner =
      case display of
        DisplayCode -> HH.div [] inner
        DisplayEditor ->
          HH.div
            [HE.onClick (\e -> pure (PreventDefault (toEvent e) StartEditor))]
            inner

renderEditor ::
     forall i a. MonadEffect a
  => Editor
  -> Array (HH.HTML (H.ComponentSlot HH.HTML (Slots i) a Command) Command)
renderEditor editor =
  case editor of
    MiscE t -> [HH.text t]
    ErrorE msg ->
      [ HH.div
          [HP.class_ (HH.ClassName "error-message")]
          [ HH.text
              (case msg of
                 FillErrors fillErrors ->
                   joinWith ", " (map fromFillError fillErrors)
                   where fromFillError =
                           case _ of
                             NoSuchGlobal name ->
                               "missing name “" <> name <> "”"
                             OtherCellProblem name ->
                               "other cell “" <> name <> "” has a problem"
                 CyclicCells names ->
                   "cells refer to eachother in a loop:" <> " " <>
                   joinWith ", " names
                 DuplicateCellName -> "this name is used twice"
                 CellRenameErrors -> "internal bug; please report!" -- TODO:make this automatic.
                 CellTypeError -> "types of values don't match up"
                 CellStepEror -> "error while evaluating formula"
                 SyntaxError -> "syntax error, did you mistype something?")
          ]
      ]
    ArrayE editors ->
      [ HH.div
          [HP.class_ (HH.ClassName "array")]
          (mapWithIndex
             (\i editor' ->
                HH.div
                  [HP.class_ (HH.ClassName "array-item")]
                  [ HH.slot
                      (SProxy :: SProxy "editor")
                      i
                      component
                      (EditorAndCode
                         { editor: editor'
                         , code: editorCode editor'
                         })
                      (\rhs ->
                         Just
                           (FinishEditing
                              (editorCode
                                 (ArrayE (editArray i (MiscE rhs) editors)))))
                  ])
             editors)
      ]

editorCode :: Editor -> String
editorCode =
  case _ of
    MiscE s -> s
    ArrayE xs -> "[" <> joinWith ", " (map editorCode xs) <> "]"
    ErrorE _ -> ""

editArray :: forall i. Int -> i -> Array i -> Array i
editArray idx i =
  mapWithIndex
    (\idx' oldi ->
       if idx == idx'
         then i
         else oldi)
