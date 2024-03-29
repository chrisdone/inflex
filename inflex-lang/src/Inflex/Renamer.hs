{-# LANGUAGE TupleSections #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ApplicativeDo #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NamedFieldPuns #-}

-- | Renamer for Inflex language.

module Inflex.Renamer
  ( renameText
  , renameParsed
  , IsRenamed(..)
  , RenameError(..)
  , ParseRenameError(..)
  , patternParam
  ) where

import           Control.Monad.State
import           Control.Monad.Validate
import           Data.Bifunctor
import           Data.Decimal
import           Data.Foldable
import           Data.List
import           Data.List.NonEmpty (NonEmpty(..))
import qualified Data.Map.Strict as M
import qualified Data.Set as Set
import           Data.Text (Text)
import qualified Data.Vector as V
import           Inflex.Instances ()
import           Inflex.Parser
import           Inflex.Type
import           Inflex.Types
import           Inflex.Types as Alternative (Alternative(..))
import           Inflex.Types as Field (FieldE(..))
import           Inflex.Types.Renamer
import           Optics hiding (Fold)

--------------------------------------------------------------------------------
-- Top-level

renameText ::
     FilePath
  -> Text
  -> Either ParseRenameError (IsRenamed (Expression Renamed))
renameText fp text = do
  expression <- first ParserErrored (parseText fp text)
  first RenamerErrors (renameParsed expression)

renameParsed ::
     Expression Parsed
  -> Either (NonEmpty RenameError) (IsRenamed (Expression Renamed))
renameParsed expression =
  let (result, (mappings, unresolvedGlobals, unresolvedUuids, nameMappings)) =
        runState
          (runValidateT
             (runRenamer
                (renameExpression
                   (Env {globals = mempty, cursor = id, scope = mempty})
                   expression)))
          mempty
   in fmap
        (\thing ->
           IsRenamed
             { thing
             , mappings
             , unresolvedGlobals
             , unresolvedUuids
             , nameMappings
             }) result

--------------------------------------------------------------------------------
-- Renamers

renameExpression :: Env -> Expression Parsed -> Renamer (Expression Renamed)
renameExpression env =
  \case
    LiteralExpression literal -> renameLiteral env literal
    LambdaExpression lambda -> fmap LambdaExpression (renameLambda env lambda)
    RecordExpression record -> fmap RecordExpression (renameRecord env record)
    PropExpression prop -> fmap PropExpression (renameProp env prop)
    ArrayExpression array -> fmap ArrayExpression (renameArray env array)
    VariantExpression variant -> fmap VariantExpression (renameVariant env variant)
    CaseExpression case' -> fmap CaseExpression (renameCase env case')
    InfixExpression infix' -> fmap InfixExpression (renameInfix env infix')
    ApplyExpression apply -> fmap ApplyExpression (renameApply env apply)
    VariableExpression variable -> renameVariable env variable
    HoleExpression hole -> fmap HoleExpression (renameHole env hole)
    GlobalExpression global -> fmap GlobalExpression (renameGlobal env global)
    CellRefExpression cellRef -> fmap CellRefExpression (renameCellRef env cellRef)

renameCellRef :: Env -> CellRef Parsed -> Renamer (CellRef Renamed)
renameCellRef env CellRef{..} = do
  final <- finalizeCursor (cursor env) TypeCursor location
  -- Make sure we add the UUID address as a dependency.
  case address of
    RefUuid uuid -> modify (over _3 (Set.insert uuid))
  pure (CellRef {location = final, typ = Nothing, ..})

renameHole :: Env -> Hole Parsed -> Renamer (Hole Renamed)
renameHole env Hole{..} = do
  final <- finalizeCursor (cursor env) TypeCursor location
  pure (Hole {location = final, typ = Nothing})

renameLiteral :: Env -> Literal Parsed -> Renamer (Expression Renamed)
renameLiteral env@Env {cursor} =
  \case
    TextLiteral LiteralText {..} -> do
      final <- finalizeCursor cursor TypeCursor location
      pure
        (LiteralExpression
           (TextLiteral LiteralText {location = final, typ = Nothing, ..}))
    NumberLiteral number -> do
      number' <- renameNumber env number
      pure
        (case numberType number' of
           Just typ
             | sigMatchesNumber typ number' ->
               LiteralExpression (NumberLiteral number')
               -- Purely an optimization to avoid a no-op. We could go
               -- further and grow ints/decs to more places if we
               -- wanted.
           _ ->
             ApplyExpression
               Apply
                 { location = BuiltIn
                 , typ = numberType number'
                 , argument = LiteralExpression (NumberLiteral number')
                 , function =
                     GlobalExpression
                       Global
                         { location = BuiltIn
                         , name =
                             let Number {number = someNumber} = number'
                              in case someNumber of
                                   IntegerNumber {} ->
                                     ExactGlobalRef FromIntegerGlobal
                                   DecimalNumber {} ->
                                     ExactGlobalRef FromDecimalGlobal
                         , scheme = RenamedScheme
                         }
                 , style = OverloadedApply
                 })
  where
    sigMatchesNumber typ Number {number} =
      case number of
        IntegerNumber {}
          | ConstantType TypeConstant {name = IntegerTypeName} <- typ -> True
        DecimalNumber Decimal {places}
          | ApplyType TypeApplication { function = ConstantType TypeConstant {name = DecimalTypeName}
                                      , argument = ConstantType TypeConstant {name = NatTypeName n}
                                      } <- typ -> n == places
        _ -> False

renameNumber :: Env -> Number Parsed -> Renamer (Number Renamed)
renameNumber env@Env {cursor} Number {..} = do
  final <- finalizeCursor cursor ExpressionCursor location
  typ' <- renameSignature env typ
  pure Number {location = final, typ = typ', ..}

renameLambda :: Env -> Lambda Parsed -> Renamer (Lambda Renamed)
renameLambda env@Env {cursor} Lambda {..} = do
  final <- finalizeCursor cursor ExpressionCursor location
  param' <- renameParam env param
  body' <-
    renameExpression
      (over
         envScopeL
         (LambdaBinding param :)
         (over envCursorL (. LambdaBodyCursor) env))
      body
  typ' <- renameSignature env typ
  pure
    Lambda
      { body = body'
      , location = final
      , param = param'
      , typ = typ'
      , ..
      }

renameRecord :: Env -> Record Parsed -> Renamer (Record Renamed)
renameRecord env@Env {cursor} Record {..} = do
  final <- finalizeCursor cursor ExpressionCursor location
  fields' <-
    traverse
      (\field@FieldE {name} ->
         renameFieldE (over envCursorL (. RecordFieldCursor name) env) field)
      fields
  typ' <- renameSignature env typ
  pure Record {fields = fields', location = final, typ = typ'}

renameProp :: Env -> Prop Parsed -> Renamer (Prop Renamed)
renameProp env@Env {cursor} Prop {..} = do
  final <- finalizeCursor cursor ExpressionCursor location
  expression' <- renameExpression (over envCursorL (. PropExpressionCursor) env) expression
  typ' <- renameSignature env typ
  pure
    Prop
      { expression = expression'
      , location = final
      , typ = typ'
      , ..
      }

renameArray :: Env -> Array Parsed -> Renamer (Array Renamed)
renameArray env@Env {cursor} Array {..} = do
  final <- finalizeCursor cursor ExpressionCursor location
  expressions' <-
    V.imapM
      (\i -> renameExpression (over envCursorL (. ArrayElementCursor i) env))
      expressions
  typ' <- renameSignature env typ
  pure Array {expressions = expressions', location = final, typ = typ', ..}

renameVariant :: Env -> Variant Parsed -> Renamer (Variant Renamed)
renameVariant env@Env {cursor} Variant {..} = do
  final <- finalizeCursor cursor ExpressionCursor location
  argument' <-
    traverse
      (renameExpression (over envCursorL (. VariantElementCursor) env))
      argument
  typ' <- renameSignature env typ
  pure Variant {argument = argument', location = final, typ = typ', ..}

renameFieldE :: Env -> FieldE Parsed -> Renamer (FieldE Renamed)
renameFieldE env@Env {cursor} FieldE {..} = do
  final <- finalizeCursor cursor TypeCursor location
  expression' <-
    renameExpression (over envCursorL (. RowFieldExpression) env) expression
  pure FieldE {location = final, expression = expression', ..}

renameCase :: Env -> Case Parsed -> Renamer (Case Renamed)
renameCase env@Env {cursor} Case {..} = do
  final <- finalizeCursor cursor ExpressionCursor location
  typ' <- renameSignature env typ
  scrutinee' <- renameExpression env scrutinee
  alternatives' <- traverse (renameAlternative env) alternatives
  pure
    Case
      { location = final
      , typ = typ'
      , alternatives = alternatives'
      , scrutinee = scrutinee'
      , ..
      }

renameAlternative :: Env -> Alternative Parsed -> Renamer (Alternative Renamed)
renameAlternative env@Env {cursor} Alternative {..} = do
  final <- finalizeCursor cursor ExpressionCursor location
  pattern'' <- renamePattern env pattern'
  let addParam =
        case patternParam pattern' of
          Nothing -> id
          Just param -> over envScopeL (CaseBinding param :)
  expression' <- renameExpression (addParam env) expression
  pure
    Alternative
      {pattern' = pattern'', expression = expression', location = final, ..}

renamePattern :: Env -> Pattern Parsed -> Renamer (Pattern Renamed)
renamePattern env =
  \case
    ParamPattern param -> fmap ParamPattern (renameParam env param)
    VariantPattern variant -> fmap VariantPattern (renameVariantP env variant)
    WildPattern hole -> fmap WildPattern (renameHole env hole)

bindingParam :: Binding s -> NonEmpty (Param s)
bindingParam =
  \case
    LambdaBinding p -> pure p
    LetBinding p -> p
    CaseBinding p -> pure p

patternParam :: Pattern s -> Maybe (Param s)
patternParam =
  \case
    ParamPattern param -> pure param
    VariantPattern VariantP {argument} -> argument
    WildPattern {} -> Nothing

renameVariantP :: Env -> VariantP Parsed -> Renamer (VariantP Renamed)
renameVariantP env@Env {cursor} VariantP {..} = do
  final <- finalizeCursor cursor ExpressionCursor location
  argument' <- traverse (renameParam env) argument
  pure VariantP {location = final, argument = argument', ..}

renameInfix :: Env -> Infix Parsed -> Renamer (Infix Renamed)
renameInfix env@Env {cursor} Infix {..} = do
  final <- finalizeCursor cursor ExpressionCursor location
  global' <- renameGlobal (over envCursorL (. InfixOpCursor) env) global
  left' <- renameExpression (over envCursorL (. InfixLeftCursor) env) left
  right' <- renameExpression (over envCursorL (. InfixRightCursor) env) right
  typ' <- renameSignature env typ
  pure
    Infix
      { left = left'
      , global = global'
      , right = right'
      , location = final
      , typ = typ'
      , ..
      }

renameGlobal :: Env -> Global Parsed -> Renamer (Global Renamed)
renameGlobal Env {cursor} Global {..} = do
  final <- finalizeCursor cursor ExpressionCursor location
  let exact name' =
        pure
          Global
            { location = final
            , scheme = RenamedScheme
            , name = ExactGlobalRef name'
            }
      op = NumericBinOpGlobal
  case name of
    ParsedTextName "*" -> exact $ op MulitplyOp
    ParsedTextName "+" -> exact $ op AddOp
    ParsedTextName "-" -> exact $ op SubtractOp
    ParsedTextName "/" -> exact $ op DivideOp
    ParsedTextName "=" -> exact $ (EqualGlobal Equal)
    ParsedTextName "/=" -> exact $ (EqualGlobal NotEqual)
    ParsedTextName ">" -> exact $ (CompareGlobal GreaterThan)
    ParsedTextName "<" -> exact $ (CompareGlobal LessThan)
    ParsedTextName "<=" -> exact $ (CompareGlobal LessEqualTo)
    ParsedTextName ">=" -> exact $ (CompareGlobal GreaterEqualTo)
    ParsedUuid uuid -> do
      modify (over _3 (Set.insert uuid))
      pure
        Global
          { location = final
          , scheme = RenamedScheme
          , name = UnresolvedUuid uuid
          }
    ParsedHash sha512 ->
      pure
        Global
          { location = final
          , scheme = RenamedScheme
          , name = ExactGlobalRef (HashGlobal sha512)
          }
    ParsedPrim fun ->
      pure
        Global
          { location = final
          , scheme = RenamedScheme
          , name = ExactGlobalRef (FunctionGlobal fun)
          }
    ParsedFromDecimal ->
      pure
        Global
          { location = final
          , scheme = RenamedScheme
          , name = ExactGlobalRef FromDecimalGlobal
          }
    ParsedFromInteger ->
      pure
        Global
          { location = final
          , scheme = RenamedScheme
          , name = ExactGlobalRef FromIntegerGlobal
          }
    _ -> Renamer (refute (pure (NotInScope name)))

renameApply :: Env -> Apply Parsed -> Renamer (Apply Renamed)
renameApply env@Env {cursor} Apply {..} = do
  function' <-
    renameExpression (over envCursorL (. ApplyFuncCursor) env) function
  argument' <-
    renameExpression (over envCursorL (. ApplyArgCursor) env) argument
  final <- finalizeCursor cursor ExpressionCursor location
  typ' <- renameSignature env typ
  pure
    Apply
      { function = function'
      , argument = argument'
      , location = final
      , typ = typ'
      , style
      }

renameVariable ::
     Env
  -> Variable Parsed
  -> Renamer (Expression Renamed)
renameVariable env@Env {scope, cursor, globals} variable@Variable { name
                                                                  , location
                                                                  , typ
                                                                  } =
  case find
         (any (\Param {name = name'} -> name' == name) . bindingParam . snd)
         (zip [0 ..] scope) of
    Nothing
      | False -> Renamer (refute (pure (NotInScopeLocal name)))
      | True -> do
        final <- finalizeCursor cursor ExpressionCursor location
        case M.lookup name globals of
          Nothing -> do
            modify (over _2 (Set.insert name))
            pure
              (GlobalExpression
                 (Global
                    { location = final
                    , name = UnresolvedGlobalText name
                    , scheme = RenamedScheme
                    }))
          Just globalRef -> do
            pure
              (GlobalExpression
                 (Global
                    { location = final
                    , name = ResolvedGlobalRef name globalRef
                    , scheme = RenamedScheme
                    }))
    Just (index, binding) -> do
      final <- finalizeCursor cursor ExpressionCursor location
      typ' <- renameSignature env typ
      finalizeCursorForName final name
      deBrujinIndex <-
        case binding of
          LambdaBinding {} -> pure (DeBrujinIndex (DeBrujinNesting index))
          CaseBinding {} -> pure (DeBrujinIndex (DeBrujinNesting index))
          LetBinding params ->
            case findIndex
                   (\Param {name = name'} -> name' == name)
                   (toList params) of
              Nothing ->
                Renamer
                  (refute (pure (BUG_MissingVariable scope globals variable)))
              Just subIndex ->
                pure
                  (DeBrujinIndexOfLet
                     (DeBrujinNesting index)
                     (IndexInLet subIndex))
      pure
        (VariableExpression
           (Variable {location = final, name = deBrujinIndex, typ = typ'}))

renameParam :: Env -> Param Parsed -> Renamer (Param Renamed)
renameParam env@Env{cursor} Param {..} = do
  final <- finalizeCursor cursor LambdaParamCursor location
  finalizeCursorForName final name
  typ' <- renameSignature env typ

  pure Param {name = (), location = final, typ = typ'}

renameSignature :: Env -> Maybe (Type Parsed) -> Renamer (Maybe (Type Renamed))
renameSignature env =
  maybe
    (pure Nothing)
    (fmap Just . renameType (over envCursorL (. SignatureCursor) env))

renameType :: Env -> Type Parsed -> Renamer (Type Renamed)
renameType env@Env {cursor} =
  \case
    FreshType location -> do
      final <- finalizeCursor cursor LambdaParamCursor location
      pure (FreshType final)
    VariableType typeVariable ->
      fmap VariableType (renameTypeVariable env typeVariable)
    ApplyType typeApplication ->
      fmap ApplyType (renameTypeApplication env typeApplication)
    ConstantType typeConstant ->
      fmap ConstantType (renameTypeConstant env typeConstant)
    RowType typeRow -> fmap RowType (renameTypeRow env typeRow)
    RecordType typeRow -> fmap RecordType (renameType env typeRow)
    VariantType typeRow -> fmap VariantType (renameType env typeRow)
    ArrayType typ -> fmap ArrayType (renameType env typ)

renameTypeConstant :: Env -> TypeConstant Parsed -> Renamer (TypeConstant Renamed)
renameTypeConstant Env{cursor} TypeConstant {..} = do
  final <- finalizeCursor cursor TypeCursor location
  pure TypeConstant {location = final, ..}

renameTypeRow :: Env -> TypeRow Parsed -> Renamer (TypeRow Renamed)
renameTypeRow env@Env {cursor} TypeRow {..} = do
  final <- finalizeCursor cursor TypeCursor location
  fields' <-
    traverse (renameField (over envCursorL (. RowFieldCursor) env)) fields
  pure TypeRow {location = final, fields = fields', typeVariable}

renameField :: Env -> Field Parsed -> Renamer (Field Renamed)
renameField env@Env{cursor} Field {..} = do
  final <- finalizeCursor cursor TypeCursor location
  typ' <- renameType (over envCursorL (. RowFieldType) env) typ
  pure Field {location = final, typ = typ', ..}

renameTypeApplication :: Env -> TypeApplication Parsed -> Renamer (TypeApplication Renamed)
renameTypeApplication env@Env {cursor} TypeApplication {function, argument, ..} = do
  function' <- renameType (over envCursorL (. TypeApplyCursor) env) function
  argument' <- renameType (over envCursorL (. TypeApplyCursor) env) argument
  final <- finalizeCursor cursor TypeCursor location
  pure
    TypeApplication
      {function = function', argument = argument', location = final, ..}

renameTypeVariable :: Env -> TypeVariable Parsed -> Renamer (TypeVariable Renamed)
renameTypeVariable Env{cursor} TypeVariable {..} = do
  final <- finalizeCursor cursor TypeCursor location
  pure TypeVariable {location = final, ..}

--------------------------------------------------------------------------------
-- Cursor operations

finalizeCursor :: CursorBuilder -> Cursor -> StagedLocation Parsed -> Renamer Cursor
finalizeCursor cursor finalCursor loc = do
  modify (over _1 (M.insert final loc))
  pure final
  where final = cursor finalCursor

finalizeCursorForName :: Cursor -> Text -> Renamer ()
finalizeCursorForName final text = do
  modify (over _4 (M.insert final text))
