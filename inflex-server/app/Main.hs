{-# LANGUAGE TupleSections #-}
{-# LANGUAGE ExtendedDefaultRules #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE QuasiQuotes #-}

import           Control.Monad.Catch (SomeException, catch, MonadThrow)
import           Control.Monad.Logger
import           Control.Monad.Reader
import           Control.Monad.Supply
import           Control.Monad.Writer
import           Data.Aeson
import           Data.HashMap.Strict (HashMap)
import qualified Data.HashMap.Strict as HM
import qualified Data.Map.Strict as M
import           Data.Maybe
import           Data.Semigroup ((<>))
import           Data.Text (Text)
import qualified Data.Text as T
import qualified Data.UUID as UUID
import qualified Data.UUID.V4 as V4
import           Duet.Context
import           Duet.Errors
import           Duet.Infer
import           Duet.Parser
import           Duet.Printer
import           Duet.Renamer
import           Duet.Setup
import           Duet.Simple
import           Duet.Stepper
import           Duet.Tokenizer
import           Duet.Types
import           GHC.Generics
import           Lucid
import           System.IO
import           Text.Lucius
import           Yesod hiding (Html)
import           Yesod.Lucid

--------------------------------------------------------------------------------
-- Main entry point

main :: IO ()
main = warpEnv App

--------------------------------------------------------------------------------
-- Types

data DecIn = DecIn
  { name :: Text
  , rhs :: Text
  } deriving (Generic, Show)
instance FromJSON DecIn where
  parseJSON j = do
    o <- parseJSON j
    DecIn <$> o .: "name" <*> o .: "rhs"

data DecOut = DecOut
  { name :: Text
  , rhs :: Text
  , result :: Either Text Text
  } deriving (Generic)
instance ToJSON DecOut where
  toJSON DecOut {name, rhs, result} =
    object
      [ "name" .= name
      , "rhs" .= rhs
      , "result" .=
        case result of
          Left {} -> "error" :: Text
          Right {} -> "success"
      , case result of
          Left e -> "error" .= e
          Right d -> "output" .= d
      ]

--------------------------------------------------------------------------------
-- Constants

maxSteps :: Int
maxSteps = 100

initialDecs :: [DecIn]
initialDecs =
  [ DecIn {name = "rate", rhs = "55.5"}
  , DecIn {name = "hours", rhs = "160.0"}
  , DecIn {name = "worked", rhs = "150.0"}
  , DecIn {name = "bill", rhs = "worked * rate"}
  , DecIn {name = "percent", rhs = "(worked / hours) * 100.0"}
  ]

--------------------------------------------------------------------------------
-- Dispatcher

data App = App
instance Yesod App

mkYesod "App" [parseRoutes|
  /appjs AppJsR GET
  /appcss AppCssR GET
  /api/refresh RefreshR POST
  / AppR GET
|]

--------------------------------------------------------------------------------
-- Routes

getAppR :: Handler (Html ())
getAppR = do
  initialDecs' <-
    liftIO
      (do decs <-
            fmap
              HM.fromList
              (traverse
                 (\dec -> do
                    uuid <- V4.nextRandom
                    pure (UUID.toText uuid, dec))
                 initialDecs)
          evaluateInputDocument decs)
  htmlWithUrl
    (do doctype_
        url <- ask
        html_
          (do head_
                (do title_ "InflexApp"
                    link_
                      [rel_ "stylesheet", type_ "text/css", href_ (url AppCssR)])
              body_
                (do script_
                      [type_ "text/javascript"]
                      (do toHtmlRaw "window['inflexDocument'] = "
                          toHtmlRaw (encode initialDecs')
                          ";")
                    script_ [type_ "text/javascript", src_ (url AppJsR)] "")))

getAppJsR :: Handler TypedContent
getAppJsR = sendFile "application/javascript" "../inflex-client/app.js"

getAppCssR :: Handler Css
getAppCssR = pure ($(luciusFile "templates/app.lucius") ())

postRefreshR :: Handler TypedContent
postRefreshR = selectRep (provideRep refreshHandler)

--------------------------------------------------------------------------------
-- Refresh handler

refreshHandler :: HandlerFor App Value
refreshHandler = do
  inputDocument :: HashMap Text DecIn <- requireCheckJsonBody
  evaluateInputDocument inputDocument

evaluateInputDocument :: Monad m => HashMap Text DecIn -> m Value
evaluateInputDocument inputDocument = do
  let parsedDocument =
        map
          (\(uuid, decIn@DecIn {name, rhs}) ->
             (uuid, Identifier (T.unpack name), rhs, parseDecIn decIn))
          (HM.toList inputDocument)
      evaluatedDocument =
        case mapM
               (\(uuid, i, rhs, r) -> fmap (uuid, i, rhs, ) (fmap snd r))
               parsedDocument of
          Left {} ->
            map
              (\(uuid, Identifier name, rhs, result) ->
                 ( uuid
                 , DecOut
                     { name = T.pack name
                     , rhs
                     , result =
                         case result of
                           Left e -> Left (T.pack (show e))
                           Right v -> Left "... [waiting]"
                     }))
              parsedDocument
          Right r -> runProgram r
  pure (toJSON (Object (fmap toJSON (HM.fromList evaluatedDocument))))

--------------------------------------------------------------------------------
-- Duet helpers

-- TOOD: Deal with max steps, should throw an error.
runProgram ::
     [(Text, Identifier, Text, Expression UnkindedType Identifier Location)]
  -> [(Text, DecOut)]
runProgram decls = map toDecOut final
  where
    toDecOut (uuid, name, rhs, result) =
      ( uuid
      , DecOut
          { name
          , rhs
          , result =
              case result of
                Left ex -> Left (T.pack (show ex))
                Right results ->
                  case results of
                    [] -> Left "No result (didn't start!)" -- TODO: Handle properly.
                    xs ->
                      if length xs > maxSteps
                        then Left "No result (didn't finish!)"
                        else Right
                               (T.pack (printExpression defaultPrint (last xs)))
          })
    final =
      case overall of
        Right k -> k
        Left e ->
          map (\(t, Identifier i, rhs, _) -> (t, T.pack i, rhs, Left e)) decls
    overall =
      runNoLoggingT
        (evalSupplyT
           (do (binds, ctx) <-
                 createContext
                   (map
                      (\(i, e) ->
                         let loc = expressionLabel e
                          in BindDecl
                               loc
                               (ImplicitBinding
                                  (ImplicitlyTypedBinding
                                     loc
                                     (i, loc)
                                     [makeAlt loc e])))
                      (map (\(uuid, ident, _, expr) -> (ident, expr)) decls))
               idx <- peek
               pure
                 (map
                    (\(uuid, Identifier i, rhs, _) ->
                       ( uuid
                       , T.pack i
                       , rhs
                       , runNoLoggingT
                           (evalSupplyT
                              (execWriterT
                                 (runStepper
                                    (maxSteps + 1)
                                    ctx
                                    (fmap (fmap typeSignatureA) binds)
                                    i))
                              [idx ..])))
                    decls))
           [1 ..])

--------------------------------------------------------------------------------
-- Parsing step

-- | Result of parsing the declaration.
data ParseResult
  = BadNameSyntax SomeException Text
  | BadExpressionSyntax Identifier SomeException Text
  deriving (Show)

-- | Parsing a declaration.
parseDecIn ::
     DecIn
  -> Either SomeException ( Identifier
                          , Expression UnkindedType Identifier Location)
parseDecIn DecIn {name, rhs} =
  case parseTextWith
         (consumeToken
            (\case
               Variable i -> pure i
               _ -> Nothing))
         (T.unpack name)
         name of
    Left e -> Left e
    Right (ident, _) ->
      case parseTextWith expParser (T.unpack name <> "'s expression") rhs of
        Left e -> Left e
        Right expr -> pure (Identifier (T.unpack ident), expr)
