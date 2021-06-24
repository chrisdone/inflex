{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TemplateHaskellQuotes #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE DuplicateRecordFields #-}

-- |

module Frisson where

import qualified Data.Aeson as Aeson
import           Data.Foldable
import           Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NE
import           Data.Text (Text)
import           Data.Vector (Vector)
import qualified Language.Haskell.TH as TH

--------------------------------------------------------------------------------
-- Types

data Rep
  = ProductRep Product
  | SumRep (NonEmpty Cons)
  | RecordRep Record
  | EnumRep (NonEmpty ConsName)
  | NewtypeRep Newtype
  deriving (Show)

data Record = Record
  { name :: ConsName
  , fields :: NonEmpty Field
  } deriving (Show)

data Product = Product
  { name :: ConsName
  , slots :: (NonEmpty Type)
  } deriving (Show)

data Newtype = Newtype
  { name :: ConsName
  , slot :: Type
  } deriving (Show)

data Field = Field
  { name :: FieldName
  , typ :: Type
  } deriving (Show)

data Cons = Cons
  { name :: ConsName
  , slots :: [Type]
  } deriving (Show)

data Type
  = ConType TypeName
  | IntType
  | TextType
  | ArrayType Type
  deriving (Show)

newtype ConsName =
  ConsName TH.Name
  deriving (Show)

newtype FieldName =
  FieldName TH.Name
  deriving (Show)

newtype TypeName =
  TypeName TH.Name
  deriving (Show)

--------------------------------------------------------------------------------
-- Top-level entry point

derive :: TH.Name -> TH.Q [TH.Dec]
derive n = do
  i <- TH.reify n
  let rep = resolveInfo i
  TH.runIO (print (n, rep))
  pure []

--------------------------------------------------------------------------------
-- Resolving Haskell types to Rep

resolveInfo :: TH.Info -> Rep
resolveInfo (TH.TyConI dec) = resolveDec dec
resolveInfo _ = error "Must be a data type."

resolveDec :: TH.Dec -> Rep
resolveDec (TH.NewtypeD _ctx _name _tys _mkind (TH.NormalC name [bangType]) _deriv) =
  NewtypeRep Newtype {name = ConsName name, slot = resolveType (snd bangType)}
resolveDec (TH.DataD _ctx _name _tys _mkind cons _deriv) =
  case cons of
    [] -> error "No constructors."
    [TH.NormalC name bangTypes] ->
      case NE.nonEmpty bangTypes of
        Just types ->
          ProductRep
            Product
              {name = ConsName name, slots = fmap (resolveType . snd) types}
        Nothing -> EnumRep (pure (ConsName name))
    [TH.RecC name bangTypes] ->
      case NE.nonEmpty bangTypes of
        Just types ->
          RecordRep
            Record
              { name = ConsName name
              , fields =
                  fmap
                    (\(name', _bang, typ) ->
                       Field {typ = resolveType typ, name = FieldName name'})
                    types
              }
        Nothing -> error "A record type MUST have fields."
    conses | Just necons <- traverse maybeConsNameOnly conses >>= NE.nonEmpty -> EnumRep necons
           | Just neconses <- NE.nonEmpty (map resolveCons conses) -> SumRep neconses
    _ -> error "Invalid type to resolve."
resolveDec _ = error "Must be a data type."

resolveCons :: TH.Con -> Cons
resolveCons (TH.NormalC name bangTypes) =
  Cons {name = ConsName name, slots = fmap (resolveType . snd) bangTypes}
resolveCons _ = error "Invalid Con type."

maybeConsNameOnly :: TH.Con -> Maybe ConsName
maybeConsNameOnly (TH.NormalC name []) = pure (ConsName name)
maybeConsNameOnly _ = Nothing

resolveType :: TH.Type -> Type
resolveType =
  \case
    TH.ConT name
      | name == ''Int -> IntType
      | name == ''Text -> TextType
      | otherwise -> ConType (TypeName name)
    TH.AppT (TH.ConT con) name
      | con == ''Vector -> ArrayType (resolveType name)
    _ -> error "Unsupported type."

--------------------------------------------------------------------------------
-- Generate Haskell-side

-- TODO: Generate FromJSON/ToJSON instances using a Rep

generateToJSONMethod :: Rep -> TH.Q TH.Exp
generateToJSONMethod =
  \case
    NewtypeRep Newtype {name = ConsName cons} ->
      TH.lamE [TH.conP cons [varP 0]] (TH.appE (TH.varE 'Aeson.toJSON) (varE 0))
    ProductRep Product {name = ConsName cons, slots} ->
      TH.lamE
        [TH.conP cons (zipWith (const . varP) [0 ..] (toList slots))]
        (TH.appE
           (TH.varE 'Aeson.toJSON)
           (TH.listE (zipWith (const . varE) [0 ..] (toList slots))))
  where
    varP = TH.varP . var
    varE = TH.varE . var
    var (i :: Int) = TH.mkName ("v_" ++ show i)

--------------------------------------------------------------------------------
-- Generate PureScript-side

-- TODO: Materialize:    caseJson, etc.
-- TODO: Dematerialize: fromArray, Foreign.Object.fromFoldable, etc.

-- TODO: View-based accessors

{-

-- Accessors:
foreign import docCells :: View Doc -> Array (View Cell) -- does not allocate
foreign import cellUUID :: View Cell -> String

-- Materialisation:
foreign import docMaterialise :: View Doc -> Doc
foreign import cellMaterialise :: View Cell -> Cell

-- Dematerialize:
foreign import docDematerialise :: Doc -> View Doc
foreign import cellDematerialise :: Cell -> View Cell

-- View/unview. O(1) operation; no-op
foreign import docView :: Json -> View Doc -- assumes well-structured JSON
foreign import docUnview :: View Doc -> Json

-}