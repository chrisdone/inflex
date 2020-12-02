{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE ApplicativeDo #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE LambdaCase #-}

-- | Fill in globals.

module Inflex.Filler where

import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import           Data.Text (Text)
import           Data.Validation
import           Inflex.Types
import           Inflex.Types.Filler

--------------------------------------------------------------------------------
-- Top-level entry points

expressionFill ::
     Map Text (Either e Hash)
  -> Expression Renamed
  -> Filler e (Expression Filled)
expressionFill globals =
  \case
    RecordExpression record -> fmap RecordExpression (recordFill globals record)
    CaseExpression case' -> fmap CaseExpression (caseFill globals case')
    IfExpression if' -> fmap IfExpression (ifFill globals if')
    PropExpression prop -> fmap PropExpression (propFill globals prop)
    HoleExpression hole -> pure (HoleExpression (holeFill hole))
    ArrayExpression array -> fmap ArrayExpression (arrayFill globals array)
    VariantExpression variant -> fmap VariantExpression (variantFill globals variant)
    LiteralExpression literal -> pure (LiteralExpression (literalFill literal))
    LambdaExpression lambda -> fmap LambdaExpression (lambdaFill globals lambda)
    LetExpression let' -> fmap LetExpression (letFill globals let')
    InfixExpression infix' -> fmap InfixExpression (infixFill globals infix')
    ApplyExpression apply -> fmap ApplyExpression (applyFill globals apply)
    VariableExpression variable ->
      pure (VariableExpression (variableFill variable))
    GlobalExpression global -> fmap GlobalExpression (globalFill globals global)

--------------------------------------------------------------------------------
-- Fillers

propFill :: Map Text (Either e Hash) -> Prop Renamed -> Filler e (Prop Filled)
propFill globals Prop {..} = do
  expression' <- expressionFill globals expression
  pure Prop {expression = expression', ..}

arrayFill :: Map Text (Either e Hash) -> Array Renamed -> Filler e (Array Filled)
arrayFill globals Array {..} = do
  expressions' <- traverse (expressionFill globals) expressions
  pure Array {expressions = expressions', ..}

variantFill :: Map Text (Either e Hash) -> Variant Renamed -> Filler e (Variant Filled)
variantFill globals Variant {..} = do
  argument' <- traverse (expressionFill globals) argument
  pure Variant {argument = argument', ..}

recordFill :: Map Text (Either e Hash) -> Record Renamed -> Filler e (Record Filled)
recordFill globals Record {..} = do
  fields' <- traverse fieldFill fields
  pure Record {fields = fields', ..}
  where
    fieldFill FieldE {location = l, ..} = do
      expression' <- expressionFill globals expression
      pure FieldE {expression = expression', location = l, ..}

caseFill :: Map Text (Either e Hash) -> Case Renamed -> Filler e (Case Filled)
caseFill globals Case {..} = do
  scrutinee' <- expressionFill globals scrutinee
  alternatives' <- traverse (alternativeFill globals) alternatives
  pure Case {alternatives = alternatives', scrutinee = scrutinee', ..}

alternativeFill ::
     Map Text (Either e Hash)
  -> Alternative Renamed
  -> Filler e (Alternative Filled)
alternativeFill globals Alternative {location = l, ..} = do
  let pattern'' = patternFill pattern'
  expression' <- expressionFill globals expression
  pure
    Alternative
      {expression = expression', location = l, pattern' = pattern'', ..}
  where
    patternFill :: Pattern Renamed -> Pattern Filled
    patternFill =
      \case
        ParamPattern Param {..} -> ParamPattern Param {..}
        VariantPattern VariantP {argument, ..} ->
          VariantPattern VariantP {argument = fmap paramFill argument, ..}

globalFill :: Map Text (Either e Hash) -> Global Renamed -> Filler e (Global Filled)
globalFill globals Global {..} = do
  case name of
    UnresolvedGlobal textName ->
      case M.lookup textName globals of
        Nothing -> Filler (Failure (pure (MissingGlobal globals textName)))
        Just result -> do
          case result of
            Left e -> Filler (Failure (pure (OtherCellError textName e)))
            Right globalRef ->
              pure
                Global {name = HashGlobal globalRef, scheme = FilledScheme, ..}
    ResolvedGlobalRef textName globalRef ->
      case M.lookup textName globals of
        Nothing -> pure Global {scheme = FilledScheme, name = globalRef, ..}
        Just result -> do
          case result of
            Left e -> Filler (Failure (pure (OtherCellError textName e)))
            Right globalRef' ->
              pure
                Global {name = HashGlobal globalRef', scheme = FilledScheme, ..}
    ExactGlobalRef globalRef ->
      pure Global {scheme = FilledScheme, name = globalRef, ..}

lambdaFill ::
     Map Text (Either e Hash)
  -> Lambda Renamed
  -> Filler e (Lambda Filled)
lambdaFill globals Lambda {..} = do
  body' <- expressionFill globals body
  pure Lambda {body = body', param = paramFill param, ..}

letFill ::
     Map Text (Either e Hash)
  -> Let Renamed
  -> Filler e (Let Filled)
letFill globals Let {..} = do
  binds' <- traverse (bindFill globals) binds
  body' <- expressionFill globals body
  pure Let {binds = binds', body = body', ..}

infixFill ::
     Map Text (Either e Hash)
  -> Infix Renamed
  -> Filler e (Infix Filled)
infixFill globals Infix {..} = do
  left' <- expressionFill globals left
  right' <- expressionFill globals right
  global' <- globalFill globals global
  pure Infix {left = left', right = right', global = global', ..}

bindFill ::
     Map Text (Either e Hash)
  -> Bind Renamed
  -> Filler e (Bind Filled)
bindFill globals Bind {..} = do
  value' <- expressionFill globals value
  pure
    Bind
      { param = paramFill param
      , value = value'
      , ..
      }

applyFill ::
     Map Text (Either e Hash)
  -> Apply Renamed
  -> Filler e (Apply Filled)
applyFill globals Apply {..} = do
  function' <- expressionFill globals function
  argument' <- expressionFill globals argument
  pure Apply
    { function = function'
    , argument = argument'
    , ..
    }

ifFill ::
     Map Text (Either e Hash)
  -> If Renamed
  -> Filler e (If Filled)
ifFill globals If {..} = do
  condition' <- expressionFill globals condition
  consequent' <- expressionFill globals consequent
  alternative' <- expressionFill globals alternative
  pure If
    { condition = condition'
    , consequent = consequent'
    , alternative = alternative'
    , ..
    }

variableFill ::
     Variable Renamed
  -> Variable Filled
variableFill Variable {..} = Variable {..}

literalFill ::
     Literal Renamed
  -> Literal Filled
literalFill =
  \case
    NumberLiteral number ->
      NumberLiteral (numberFill number)
    TextLiteral LiteralText {..} ->
      TextLiteral LiteralText {..}

numberFill ::
     Number Renamed
  -> Number Filled
numberFill Number {..} = Number {..}

paramFill ::
     Param Renamed
  -> Param Filled
paramFill Param {..} = Param {..}

holeFill ::
     Hole Renamed
  -> Hole Filled
holeFill Hole {..} = Hole {..}
