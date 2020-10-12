-- | Shared data types.

module Inflex.Schema where

import Affjax as AX
import Affjax.RequestBody as RequestBody
import Affjax.ResponseFormat as ResponseFormat
import Control.Monad.Except (runExcept)
import Data.Argonaut.Core (stringify) as J
import Data.Argonaut.Parser (jsonParser) as J
import Data.Either (Either(..))
import Data.Generic.Rep (class Generic)
import Data.Generic.Rep.Show (genericShow)
import Data.Maybe (Maybe(..))
import Data.UUID (UUID)
import Effect.Aff.Class (class MonadAff)
import Effect.Class.Console (log, error)
import Foreign (F, Foreign, ForeignError(..), fail)
import Foreign.Generic (class Decode, class Encode, genericDecode, genericDecodeJSON, genericEncode, genericEncodeJSON, decode, encode)
import Foreign.Generic.Class (class GenericDecode, class GenericEncode)
import Halogen as H
import Inflex.Json (opts)
import Prelude

--------------------------------------------------------------------------------
-- Types

type Vector a = Array a

type Text = String

{-

GUIDELINE

If you change a type by

* removing/adding a field

then you need to bump its schema version, copy the old type deprecated
(and update all types that refer to this). Do that recursively.

If you change a type by

* changing a used type's version

then you don't need to bump its schema, UNLESS that type is used elsewhere.

ALSO, check your ./rpc file.

-}

class Version v where
  versionNumber :: v -> Int
  versionRefl :: v

data Version1 = Version1
data Version2 = Version2

data None =
  None

newtype DocumentId =
  DocumentId Int

data OutputDocument = OutputDocument
  { cells :: Vector OutputCell
  }

data RefreshDocument = RefreshDocument
  { document :: InputDocument1
  , documentId :: DocumentId
  }

data InputDocument1 = InputDocument1
  { cells :: Vector InputCell1
  }

data OutputCell = OutputCell
  { uuid :: UUID
  , name :: Text
  , code :: Text
  , result :: Result
  , order :: Int
  }

data InputCell1 = InputCell1
  { uuid :: UUID
  , name :: Text
  , code :: Text
  , order :: Int
  , version :: Version1
  }

data Result
  = ResultError CellError
  | ResultOk ResultTree

newtype ResultTree =
  ResultTree Tree2

data Tree2
  = ArrayTree2 Version2 OriginalSource (Vector Tree2)
  | RecordTree2 Version2 OriginalSource (Vector Field2)
  | MiscTree2 Version2 OriginalSource Text

data Field2 = Field2
  { version :: Version2
  , key :: Text
  , value :: Tree2
  }

data OriginalSource
  = OriginalSource Text
  | NoOriginalSource

data CellError
  = SyntaxError -- TODO: more info.
  | FillErrors (Vector FillError)
  | CyclicCells (Vector Text)
  | DuplicateCellName
  | CellRenameErrors
  | CellTypeError -- TODO: more info.
  | CellStepEror -- TODO: more info.

data FillError
  = NoSuchGlobal Text
  | OtherCellProblem Text


--------------------------------------------------------------------------------
-- Deprecated

{-# DEPRECATED InputDocument "Use InputDocument1" #-}
data InputDocument = InputDocument
  { cells :: Vector InputCell
  }

{-# DEPRECATED InputCell "Use InputCell1" #-}
data InputCell = InputCell
  { uuid :: UUID
  , name :: Text
  , code :: Text
  }

{-# DEPRECATED Tree1 "Use Tree2" #-}
data Tree1
  = ArrayTree Version1 (Vector Tree1)
  | RecordTree Version1 (Vector Field1)
  | MiscTree Version1 Text

{-# DEPRECATED Field1 "Use Field2" #-}
data Field1 = Field1
  { version :: Version1
  , key :: Text
  , value :: Tree1
  }


--------------------------------------------------------------------------------
-- Derivings

derive instance genericNone :: Generic None _
instance showNone :: Show None where show = genericShow
instance decodeNone :: Decode None where decode = genericDecode opts
instance encodeNone :: Encode None where encode = genericEncode opts

derive instance genericResult :: Generic Result _
instance showResult :: Show Result where show = genericShow
instance decodeResult :: Decode Result where decode = genericDecode opts
instance encodeResult :: Encode Result where encode = genericEncode opts

derive instance genericTree1 :: Generic Tree1 _
instance showTree1 :: Show Tree1 where show x = genericShow x
instance decodeTree1 :: Decode Tree1 where decode x = genericDecode opts x
instance encodeTree1 :: Encode Tree1 where encode x = genericEncode opts x

derive instance genericTree2 :: Generic Tree2 _
instance showTree2 :: Show Tree2 where show x = genericShow x
instance decodeTree2 :: Decode Tree2 where decode x = genericDecode opts x
instance encodeTree2 :: Encode Tree2 where encode x = genericEncode opts x

derive instance genericResultTree :: Generic ResultTree _
instance showResultTree :: Show ResultTree where show x = genericShow x
instance encodeResultTree :: Encode ResultTree where encode (ResultTree tree) = encode tree
instance decodeResultTree :: Decode ResultTree where decode x = genericDecode opts x

derive instance genericCellError :: Generic CellError _
instance showCellError :: Show CellError where show = genericShow
instance decodeCellError :: Decode CellError where decode = genericDecode opts
instance encodeCellError :: Encode CellError where encode = genericEncode opts

derive instance genericField1 :: Generic Field1 _
instance showField1 :: Show Field1 where show x = genericShow x
instance decodeField1 :: Decode Field1 where decode x = genericDecode opts x
instance encodeField1 :: Encode Field1 where encode x = genericEncode opts x

derive instance genericField2 :: Generic Field2 _
instance showField2 :: Show Field2 where show x = genericShow x
instance decodeField2 :: Decode Field2 where decode x = genericDecode opts x
instance encodeField2 :: Encode Field2 where encode x = genericEncode opts x

derive instance genericFillError :: Generic FillError _
instance showFillError :: Show FillError where show = genericShow
instance decodeFillError :: Decode FillError where decode = genericDecode opts
instance encodeFillError :: Encode FillError where encode = genericEncode opts

derive instance genericOriginalSource :: Generic OriginalSource _
instance showOriginalSource :: Show OriginalSource where show = genericShow
instance decodeOriginalSource :: Decode OriginalSource where decode = genericDecode opts
instance encodeOriginalSource :: Encode OriginalSource where encode = genericEncode opts

derive instance genericInputDocument :: Generic InputDocument _
instance showInputDocument :: Show InputDocument where show = genericShow
instance decodeInputDocument :: Decode InputDocument where decode = genericDecode opts
instance encodeInputDocument :: Encode InputDocument where encode = genericEncode opts

derive instance genericInputDocument1 :: Generic InputDocument1 _
instance showInputDocument1 :: Show InputDocument1 where show = genericShow
instance decodeInputDocument1 :: Decode InputDocument1 where decode = genericDecode opts
instance encodeInputDocument1 :: Encode InputDocument1 where encode = genericEncode opts

derive instance genericRefreshDocument :: Generic RefreshDocument _
instance showRefreshDocument :: Show RefreshDocument where show = genericShow
instance decodeRefreshDocument :: Decode RefreshDocument where decode = genericDecode opts
instance encodeRefreshDocument :: Encode RefreshDocument where encode = genericEncode opts

derive instance genericOutputDocument :: Generic OutputDocument _
instance showOutputDocument :: Show OutputDocument where show = genericShow
instance decodeOutputDocument :: Decode OutputDocument where decode = genericDecode opts
instance encodeOutputDocument :: Encode OutputDocument where encode = genericEncode opts

derive instance genericInputCell :: Generic InputCell _
instance showInputCell :: Show InputCell where show = genericShow
instance decodeInputCell :: Decode InputCell where decode = genericDecode opts
instance encodeInputCell :: Encode InputCell where encode = genericEncode opts

derive instance genericInputCell1 :: Generic InputCell1 _
instance showInputCell1 :: Show InputCell1 where show = genericShow
instance decodeInputCell1 :: Decode InputCell1 where decode = genericDecode opts
instance encodeInputCell1 :: Encode InputCell1 where encode = genericEncode opts

derive instance genericOutputCell :: Generic OutputCell _
instance showOutputCell :: Show OutputCell where show = genericShow
instance decodeOutputCell :: Decode OutputCell where decode = genericDecode opts
instance encodeOutputCell :: Encode OutputCell where encode = genericEncode opts

derive instance genericDocumentId :: Generic DocumentId _
instance showDocumentId :: Show DocumentId where show = genericShow
instance decodeDocumentId :: Decode DocumentId where decode = genericDecode opts
instance encodeDocumentId :: Encode DocumentId where encode = genericEncode opts

--------------------------------------------------------------------------------
-- RPC call

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

--------------------------------------------------------------------------------
-- Version infra

parseVersion :: forall v. Version v => Foreign -> F v
parseVersion j = do
  i <- decode j
  if i == versionNumber (versionRefl :: v)
    then pure (versionRefl :: v)
    else fail
           (TypeMismatch
              ("Version" <> show (versionNumber (versionRefl :: v)))
              ("Version" <> show i))

versionToJSON :: forall v. Version v => v -> Foreign
versionToJSON v = encode (versionNumber v)

--------------------------------------------------------------------------------
-- Versions

instance versionVersion1 :: Version Version1 where
  versionNumber _ = 1
  versionRefl = Version1
derive instance genericVersion1 :: Generic Version1 _
instance showVersion1 :: Show Version1 where show = genericShow
instance decodeVersion1 :: Decode Version1 where decode = parseVersion
instance encodeVersion1 :: Encode Version1 where encode = versionToJSON

instance versionVersion2 :: Version Version2 where
  versionNumber _ = 2
  versionRefl = Version2
derive instance genericVersion2 :: Generic Version2 _
instance showVersion2 :: Show Version2 where show = genericShow
instance decodeVersion2 :: Decode Version2 where decode = parseVersion
instance encodeVersion2 :: Encode Version2 where encode = versionToJSON
