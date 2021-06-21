-- | Shared data types.

module Inflex.Rpc where

import Data.String as String
import Affjax as AX
import Affjax.RequestBody as RequestBody
import Affjax.ResponseFormat as ResponseFormat
import Control.Monad.Except (runExcept)
import Data.Argonaut.Core (stringify) as J
import Data.Argonaut.Parser as J
import Data.Either (Either(..))
import Data.Generic.Rep (class Generic)
import Data.Maybe (Maybe(..))
import Effect.Aff.Class (class MonadAff)
import Effect.Class.Console (error, log)
import Foreign.Generic (genericDecodeJSON, genericEncodeJSON)
import Foreign.Generic.Class (class GenericDecode, class GenericEncode)
import Halogen as H
import Inflex.Json (opts)
import Inflex.Schema
import Prelude (class Show, bind, discard, pure, show, (<>))

rpcCsvCheckSchema :: forall m. MonadAff m => CsvImportSpec -> m (Either String CsvCheckStatus)
rpcCsvCheckSchema = rpcCall "CsvCheckSchema"

rpcCsvGuessSchema :: forall m. MonadAff m => File -> m (Either String CsvGuess)
rpcCsvGuessSchema = rpcCall "CsvGuessSchema"

rpcCsvImport :: forall m. MonadAff m => CsvImportFinal -> m (Either String OutputDocument)
rpcCsvImport = rpcCall "CsvImport"

rpcGetFiles :: forall m. MonadAff m => FileQuery -> m (Either String FilesOutput)
rpcGetFiles = rpcCall "GetFiles"

rpcLoadDocument :: forall m. MonadAff m => DocumentId -> m (Either String OutputDocument)
rpcLoadDocument = rpcCall "LoadDocument"

rpcRedoDocument :: forall m. MonadAff m => DocumentId -> m (Either String OutputDocument)
rpcRedoDocument = rpcCall "RedoDocument"

rpcUndoDocument :: forall m. MonadAff m => DocumentId -> m (Either String OutputDocument)
rpcUndoDocument = rpcCall "UndoDocument"

rpcUpdateDocument :: forall m. MonadAff m => UpdateDocument -> m (Either String UpdateResult)
rpcUpdateDocument = rpcCall "UpdateDocument"

rpcUpdateSandbox :: forall m. MonadAff m => UpdateSandbox -> m (Either String UpdateResult)
rpcUpdateSandbox = rpcCall "UpdateSandbox"



--------------------------------------------------------------------------------
-- API call

-- TODO: Fix the double encoding and double decoding here.
rpcCall
  :: forall m input output i o
  .  MonadAff m
  => GenericEncode i
  => GenericDecode o
  => Generic input i
  => Generic output o
  => Show output
  => Show input
  => String
  -> input
  -> m (Either String output)
rpcCall endpoint0 input =
  H.liftAff
    (do case J.jsonParser (genericEncodeJSON opts input) of
          Left e -> do
            error ("Own JSON was invalid! " <> e)
            pure (Left e)
          Right json -> do
            log "Sending POST"
            result <-
              H.liftAff
                (AX.post
                   ResponseFormat.string
                   endpoint
                   (Just (RequestBody.json json)))
            case result of
              Left err -> do
                error
                  ("POST " <> endpoint <>
                   " response failed to decode:" <>
                   AX.printError err)
                pure (Left (AX.printError err))
              Right response -> do
                log "Got result as String, parsing with Foreign.Generic"
                log ("Length: " <> show (String.length (response.body)))
                case runExcept (genericDecodeJSON opts (response . body)) of
                  Right r -> do
                    log "Decoded."
                    pure (Right r)
                  Left e -> do
                    error ("Failed to decode:" <> show e)
                    pure (Left (show e)))
  where
    endpoint = "/api/rpc/" <> endpoint0
