-- | Shared data types.

module Inflex.Rpc where

import Data.Generic.Rep (class Generic)
import Data.Generic.Rep.Show (genericShow)
import Data.UUID (UUID)
import Foreign.Generic (class Decode, class Encode, SumEncoding, defaultOptions, genericDecode, genericEncode)
import Inflex.Json (opts)
import Prelude (Unit, bind, const, discard, map, mempty, pure, ($), (<>), show, unit, Unit, bind, const, discard, map, mempty, pure, show, unit, ($), (<>), class Show)

import Affjax as AX
import Affjax.RequestBody as RequestBody
import Affjax.ResponseFormat as ResponseFormat
import Control.Monad.Except (runExcept)
import Control.Monad.State (class MonadState)
import Data.Argonaut.Core (stringify) as J
import Data.Argonaut.Parser (jsonParser) as J
import Data.Either (Either(..))
import Data.Generic.Rep
import Halogen as H

import Data.Map (Map)
import Data.Map as M
import Data.Maybe (Maybe(..))
import Data.Maybe (Maybe)

import Data.Symbol (SProxy(..))

import Data.Tuple (Tuple(..))
import Data.UUID (UUID, genUUIDV4, uuidToString)
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Aff.Class (class MonadAff)
import Effect.Class (class MonadEffect)
import Effect.Class.Console (log, error)
import Foreign.Generic (genericDecodeJSON, genericEncodeJSON, class GenericDecode, class GenericEncode)
import Foreign.Generic.Class (class GenericDecode, class GenericEncode)

import Inflex.Schema

rpcLoadDocument :: forall m. MonadAff m => DocumentId -> m (Either String OutputDocument)
rpcLoadDocument = rpcCall "LoadDocument"

rpcRefreshDocument :: forall m. MonadAff m => RefreshDocument -> m (Either String OutputDocument)
rpcRefreshDocument = rpcCall "RefreshDocument"



-- TODO: Fix the double encoding and double decoding here.
rpcCall
  :: forall m input output i o
  .  MonadAff m
  => GenericEncode i
  => GenericDecode o
  => Generic input i
  => Generic output o
  => Show output
  => String
  -> input
  -> m (Either String output)
rpcCall endpoint0 input =
  H.liftAff
    (do log ("POST " <> endpoint)
        case J.jsonParser (genericEncodeJSON opts input) of
          Left e -> do
            error ("Own JSON was invalid! " <> e)
            pure (Left e)
          Right json -> do
            result <-
              H.liftAff
                (AX.post
                   ResponseFormat.json
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
                log $
                  "POST " <> endpoint <> " response:" <>
                  (J.stringify (response . body))
                case runExcept
                       (genericDecodeJSON opts (J.stringify (response . body))) of
                  Right r -> do
                    log ("OK, decoded:" <> show r)
                    pure (Right r)
                  Left e -> do
                    error ("Failed to decode:" <> show e)
                    pure (Left (show e)))
  where endpoint = "/api/rpc/" <> endpoint0
