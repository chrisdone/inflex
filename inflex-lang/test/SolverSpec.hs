{-# LANGUAGE RecordWildCards, TemplateHaskell, ViewPatterns #-}
{-# OPTIONS -F -pgmF=early #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DuplicateRecordFields #-}
-- |

module SolverSpec where

import           Control.Early
import qualified Data.HashMap.Strict as HM
import           Data.List.NonEmpty (NonEmpty(..))
import qualified Data.Map.Strict as M
import           Data.Sequence (Seq)
import qualified Data.Sequence as Seq
import           Data.Text (Text)
import           Inflex.Instances ()
import           Inflex.Solver
import           Inflex.Type
import           Inflex.Types
import           Match
import qualified RIO
import           Test.Hspec

solveText' :: (e ~ ()) =>
     M.Map Hash (Either e (Scheme Polymorphic))
  -> FilePath
  -> Text
  -> IO (Either (GenerateSolveError e) (IsSolved (Expression Solved)))
solveText' hash fp text = do
  counter <- RIO.newSomeRef 0
  binds <- RIO.newSomeRef mempty
  fmap
    (fmap (\IsSolved {..} -> IsSolved {mappings = mempty, ..}))
    (RIO.runRIO
       SolveReader {glogfunc = mempty, counter, binds}
       (solveText hash fp text))

unifyConstraints' ::
     Seq EqualityConstraint
  -> IO (Either (SolveError) (Seq Substitution))
unifyConstraints' cs = do
  counter <- RIO.newSomeRef 0
  binds <- RIO.newSomeRef mempty
  RIO.runRIO SolveReader {glogfunc = mempty, counter, binds} $
    runSolver
      (do unifyConstraints cs?
          fmap
            (Right . fmap (uncurry Substitution) . Seq.fromList . HM.toList)
            freezeSubstitutions)

unifyAndSubstitute' ::
     Seq EqualityConstraint
  -> Type Generated
  -> IO (Either (SolveError) (Type Solved))
unifyAndSubstitute' x cs = do
  counter <- RIO.newSomeRef 0
  binds <- RIO.newSomeRef mempty
  RIO.runRIO SolveReader {glogfunc = mempty, counter, binds} . runSolver . unifyAndSubstitute x $ cs

spec :: Spec
spec = do
  describe "Fine-grained" fineGrained
  describe "Coarse-grained" coarseGrained
  describe "Regression" regression

--------------------------------------------------------------------------------
-- Coarse-grained tests

coarseGrained :: Spec
coarseGrained = do
  arrays
  variants
  describe
    "Successful"
    (do it
          "r:r.x"
          (shouldReturn
             (fmap
                (fmap (expressionType . Inflex.Solver.thing))
                (solveText' mempty "" "r:(r.x)"))
             (Right
                (ApplyType
                   (TypeApplication
                      { function =
                          ApplyType
                            (TypeApplication
                               { function =
                                   ConstantType
                                     (TypeConstant
                                        { location = ExpressionCursor
                                        , name = FunctionTypeName
                                        })
                               , argument =
                                   RecordType
                                     (RowType
                                        (TypeRow
                                           { location =
                                               LambdaBodyCursor ExpressionCursor
                                           , typeVariable =
                                               Just
                                                 (TypeVariable
                                                    { location =
                                                        LambdaBodyCursor
                                                          ExpressionCursor
                                                    , prefix = RowVarPrefix
                                                    , index = 1
                                                    , kind = RowKind
                                                    })
                                           , fields =
                                               [ Field
                                                   { location =
                                                       LambdaBodyCursor
                                                         ExpressionCursor
                                                   , name =
                                                       FieldName
                                                         {unFieldName = "x"}
                                                   , typ =
                                                       VariableType
                                                         (TypeVariable
                                                            { location =
                                                                LambdaBodyCursor
                                                                  ExpressionCursor
                                                            , prefix =
                                                                FieldTypePrefix
                                                            , index = 3
                                                            , kind = TypeKind
                                                            })
                                                   }
                                               ]
                                           }))
                               , location = ExpressionCursor
                               , kind = FunKind TypeKind TypeKind
                               })
                      , argument =
                          VariableType
                            (TypeVariable
                               { location = LambdaBodyCursor ExpressionCursor
                               , prefix = FieldTypePrefix
                               , index = 3
                               , kind = TypeKind
                               })
                      , location = ExpressionCursor
                      , kind = TypeKind
                      }))))
        it
          "[{x:1},{x:1}]"
          (shouldReturnSatisfy
             (fmap (fmap Inflex.Solver.thing) (solveText' mempty "" "[{x:1},{x:1}]"))
             $(match [|Right (ArrayExpression (Array {form = (), expressions = [RecordExpression (Record {fields = [FieldE {name = FieldName {unFieldName = "x"}, expression = ApplyExpression (Apply {location = BuiltIn, function = GlobalExpression (Global {location = BuiltIn, name = FromIntegerGlobal, scheme = SolvedScheme (Scheme {location = BuiltIn, constraints = [ClassConstraint {className = FromIntegerClassName, typ = VariableType (TypeVariable {location = ArrayElementCursor 0 (RecordFieldCursor (FieldName {unFieldName = "x"}) (RowFieldExpression ExpressionCursor)), prefix = ApplyPrefix, index = 2, kind = TypeKind}) :| [], location = BuiltIn}], typ = ApplyType (TypeApplication {function = ApplyType (TypeApplication {function = ConstantType (TypeConstant {location = BuiltIn, name = FunctionTypeName}), argument = ConstantType (TypeConstant {location = BuiltIn, name = IntegerTypeName}), location = BuiltIn, kind = FunKind TypeKind TypeKind}), argument = VariableType (TypeVariable {location = ArrayElementCursor 0 (RecordFieldCursor (FieldName {unFieldName = "x"}) (RowFieldExpression ExpressionCursor)), prefix = ApplyPrefix, index = 2, kind = TypeKind}), location = BuiltIn, kind = TypeKind})})}), argument = LiteralExpression (NumberLiteral (Number {location = ArrayElementCursor 0 (RecordFieldCursor (FieldName {unFieldName = "x"}) (RowFieldExpression ExpressionCursor)), number = IntegerNumber 1, typ = ConstantType (TypeConstant {location = ArrayElementCursor 0 (RecordFieldCursor (FieldName {unFieldName = "x"}) (RowFieldExpression ExpressionCursor)), name = IntegerTypeName})})), typ = VariableType (TypeVariable {location = ArrayElementCursor 0 (RecordFieldCursor (FieldName {unFieldName = "x"}) (RowFieldExpression ExpressionCursor)), prefix = ApplyPrefix, index = 2, kind = TypeKind})}), location = ArrayElementCursor 0 (RecordFieldCursor (FieldName {unFieldName = "x"}) TypeCursor)}], location = ArrayElementCursor 0 ExpressionCursor, typ = RecordType (RowType (TypeRow {location = ArrayElementCursor 0 ExpressionCursor, typeVariable = Nothing, fields = [Field {location = ArrayElementCursor 0 (RecordFieldCursor (FieldName {unFieldName = "x"}) TypeCursor), name = FieldName {unFieldName = "x"}, typ = VariableType (TypeVariable {location = ArrayElementCursor 0 (RecordFieldCursor (FieldName {unFieldName = "x"}) (RowFieldExpression ExpressionCursor)), prefix = ApplyPrefix, index = 2, kind = TypeKind})}]}))}),RecordExpression (Record {fields = [FieldE {name = FieldName {unFieldName = "x"}, expression = ApplyExpression (Apply {location = BuiltIn, function = GlobalExpression (Global {location = BuiltIn, name = FromIntegerGlobal, scheme = SolvedScheme (Scheme {location = BuiltIn, constraints = [ClassConstraint {className = FromIntegerClassName, typ = VariableType (TypeVariable {location = ArrayElementCursor 0 (RecordFieldCursor (FieldName {unFieldName = "x"}) (RowFieldExpression ExpressionCursor)), prefix = ApplyPrefix, index = 2, kind = TypeKind}) :| [], location = BuiltIn}], typ = ApplyType (TypeApplication {function = ApplyType (TypeApplication {function = ConstantType (TypeConstant {location = BuiltIn, name = FunctionTypeName}), argument = ConstantType (TypeConstant {location = BuiltIn, name = IntegerTypeName}), location = BuiltIn, kind = FunKind TypeKind TypeKind}), argument = VariableType (TypeVariable {location = ArrayElementCursor 0 (RecordFieldCursor (FieldName {unFieldName = "x"}) (RowFieldExpression ExpressionCursor)), prefix = ApplyPrefix, index = 2, kind = TypeKind}), location = BuiltIn, kind = TypeKind})})}), argument = LiteralExpression (NumberLiteral (Number {location = ArrayElementCursor 1 (RecordFieldCursor (FieldName {unFieldName = "x"}) (RowFieldExpression ExpressionCursor)), number = IntegerNumber 1, typ = ConstantType (TypeConstant {location = ArrayElementCursor 1 (RecordFieldCursor (FieldName {unFieldName = "x"}) (RowFieldExpression ExpressionCursor)), name = IntegerTypeName})})), typ = VariableType (TypeVariable {location = ArrayElementCursor 0 (RecordFieldCursor (FieldName {unFieldName = "x"}) (RowFieldExpression ExpressionCursor)), prefix = ApplyPrefix, index = 2, kind = TypeKind})}), location = ArrayElementCursor 1 (RecordFieldCursor (FieldName {unFieldName = "x"}) TypeCursor)}], location = ArrayElementCursor 1 ExpressionCursor, typ = RecordType (RowType (TypeRow {location = ArrayElementCursor 1 ExpressionCursor, typeVariable = Nothing, fields = [Field {location = ArrayElementCursor 1 (RecordFieldCursor (FieldName {unFieldName = "x"}) TypeCursor), name = FieldName {unFieldName = "x"}, typ = VariableType (TypeVariable {location = ArrayElementCursor 0 (RecordFieldCursor (FieldName {unFieldName = "x"}) (RowFieldExpression ExpressionCursor)), prefix = ApplyPrefix, index = 2, kind = TypeKind})}]}))})], typ = ArrayType (RecordType (RowType (TypeRow {location = ArrayElementCursor 0 ExpressionCursor, typeVariable = Nothing, fields = [Field {location = ArrayElementCursor 0 (RecordFieldCursor (FieldName {unFieldName = "x"}) TypeCursor), name = FieldName {unFieldName = "x"}, typ = VariableType (TypeVariable {location = ArrayElementCursor 0 (RecordFieldCursor (FieldName {unFieldName = "x"}) (RowFieldExpression ExpressionCursor)), prefix = ApplyPrefix, index = 2, kind = TypeKind})}]}))), location = ExpressionCursor}))|]))
        it
          "{x:1}"
          (shouldReturnSatisfy
             (fmap (fmap Inflex.Solver.thing) (solveText' mempty "" "{x:1}"))
             $(match [|Right
                         (RecordExpression
                            (Record
                               { fields =
                                   [ FieldE
                                       { name = FieldName {unFieldName = "x"}
                                       , expression =
                                           ApplyExpression
                                             (Apply
                                                { location = BuiltIn
                                                , function =
                                                    GlobalExpression
                                                      (Global
                                                         { location = BuiltIn
                                                         , name = FromIntegerGlobal
                                                         , scheme =
                                                             SolvedScheme
                                                               (Scheme
                                                                  { location = BuiltIn
                                                                  , constraints =
                                                                      [ ClassConstraint
                                                                          { className =
                                                                              FromIntegerClassName
                                                                          , typ =
                                                                              VariableType
                                                                                (TypeVariable
                                                                                   { location =
                                                                                       RecordFieldCursor
                                                                                         (FieldName
                                                                                            { unFieldName =
                                                                                                "x"
                                                                                            })
                                                                                         (RowFieldExpression
                                                                                            ExpressionCursor)
                                                                                   , prefix =
                                                                                       ApplyPrefix
                                                                                   , index =
                                                                                       1
                                                                                   , kind =
                                                                                       TypeKind
                                                                                   }) :|
                                                                              []
                                                                          , location =
                                                                              BuiltIn
                                                                          }
                                                                      ]
                                                                  , typ =
                                                                      ApplyType
                                                                        (TypeApplication
                                                                           { function =
                                                                               ApplyType
                                                                                 (TypeApplication
                                                                                    { function =
                                                                                        ConstantType
                                                                                          (TypeConstant
                                                                                             { location =
                                                                                                 BuiltIn
                                                                                             , name =
                                                                                                 FunctionTypeName
                                                                                             })
                                                                                    , argument =
                                                                                        ConstantType
                                                                                          (TypeConstant
                                                                                             { location =
                                                                                                 BuiltIn
                                                                                             , name =
                                                                                                 IntegerTypeName
                                                                                             })
                                                                                    , location =
                                                                                        BuiltIn
                                                                                    , kind =
                                                                                        FunKind
                                                                                          TypeKind
                                                                                          TypeKind
                                                                                    })
                                                                           , argument =
                                                                               VariableType
                                                                                 (TypeVariable
                                                                                    { location =
                                                                                        RecordFieldCursor
                                                                                          (FieldName
                                                                                             { unFieldName =
                                                                                                 "x"
                                                                                             })
                                                                                          (RowFieldExpression
                                                                                             ExpressionCursor)
                                                                                    , prefix =
                                                                                        ApplyPrefix
                                                                                    , index =
                                                                                        1
                                                                                    , kind =
                                                                                        TypeKind
                                                                                    })
                                                                           , location =
                                                                               BuiltIn
                                                                           , kind =
                                                                               TypeKind
                                                                           })
                                                                  })
                                                         })
                                                , argument =
                                                    LiteralExpression
                                                      (NumberLiteral
                                                         (Number
                                                            { location =
                                                                RecordFieldCursor
                                                                  (FieldName
                                                                     {unFieldName = "x"})
                                                                  (RowFieldExpression
                                                                     ExpressionCursor)
                                                            , number = IntegerNumber 1
                                                            , typ =
                                                                ConstantType
                                                                  (TypeConstant
                                                                     { location =
                                                                         RecordFieldCursor
                                                                           (FieldName
                                                                              { unFieldName =
                                                                                  "x"
                                                                              })
                                                                           (RowFieldExpression
                                                                              ExpressionCursor)
                                                                     , name =
                                                                         IntegerTypeName
                                                                     })
                                                            }))
                                                , typ =
                                                    VariableType
                                                      (TypeVariable
                                                         { location =
                                                             RecordFieldCursor
                                                               (FieldName
                                                                  {unFieldName = "x"})
                                                               (RowFieldExpression
                                                                  ExpressionCursor)
                                                         , prefix = ApplyPrefix
                                                         , index = 1
                                                         , kind = TypeKind
                                                         })
                                                })
                                       , location =
                                           RecordFieldCursor
                                             (FieldName {unFieldName = "x"})
                                             TypeCursor
                                       }
                                   ]
                               , location = ExpressionCursor
                               , typ =
                                   RecordType
                                     (RowType
                                        (TypeRow
                                           { location = ExpressionCursor
                                           , typeVariable = Nothing
                                           , fields =
                                               [ Field
                                                   { location =
                                                       RecordFieldCursor
                                                         (FieldName {unFieldName = "x"})
                                                         TypeCursor
                                                   , name = FieldName {unFieldName = "x"}
                                                   , typ =
                                                       VariableType
                                                         (TypeVariable
                                                            { location =
                                                                RecordFieldCursor
                                                                  (FieldName
                                                                     {unFieldName = "x"})
                                                                  (RowFieldExpression
                                                                     ExpressionCursor)
                                                            , prefix = ApplyPrefix
                                                            , index = 1
                                                            , kind = TypeKind
                                                            })
                                                   }
                                               ]
                                           }))
                               }))|]))
        it
          "{x:1}.x"
          (shouldReturnSatisfy
             (fmap (fmap Inflex.Solver.thing) (solveText' mempty "" "{x:1}.x"))
             $(match [|Right
                         (PropExpression
                            (Prop
                               { expression =
                                   RecordExpression
                                     (Record
                                        { fields =
                                            [ FieldE
                                                { name = FieldName {unFieldName = "x"}
                                                , expression =
                                                    ApplyExpression
                                                      (Apply
                                                         { location = BuiltIn
                                                         , function =
                                                             GlobalExpression
                                                               (Global
                                                                  { location = BuiltIn
                                                                  , name =
                                                                      FromIntegerGlobal
                                                                  , scheme =
                                                                      SolvedScheme
                                                                        (Scheme
                                                                           { location =
                                                                               BuiltIn
                                                                           , constraints =
                                                                               [ ClassConstraint
                                                                                   { className =
                                                                                       FromIntegerClassName
                                                                                   , typ =
                                                                                       VariableType
                                                                                         (TypeVariable
                                                                                            { location =
                                                                                                PropExpressionCursor
                                                                                                  (RecordFieldCursor
                                                                                                     (FieldName
                                                                                                        { unFieldName =
                                                                                                            "x"
                                                                                                        })
                                                                                                     (RowFieldExpression
                                                                                                        ExpressionCursor))
                                                                                            , prefix =
                                                                                                ApplyPrefix
                                                                                            , index =
                                                                                                2
                                                                                            , kind =
                                                                                                TypeKind
                                                                                            }) :|
                                                                                       []
                                                                                   , location =
                                                                                       BuiltIn
                                                                                   }
                                                                               ]
                                                                           , typ =
                                                                               ApplyType
                                                                                 (TypeApplication
                                                                                    { function =
                                                                                        ApplyType
                                                                                          (TypeApplication
                                                                                             { function =
                                                                                                 ConstantType
                                                                                                   (TypeConstant
                                                                                                      { location =
                                                                                                          BuiltIn
                                                                                                      , name =
                                                                                                          FunctionTypeName
                                                                                                      })
                                                                                             , argument =
                                                                                                 ConstantType
                                                                                                   (TypeConstant
                                                                                                      { location =
                                                                                                          BuiltIn
                                                                                                      , name =
                                                                                                          IntegerTypeName
                                                                                                      })
                                                                                             , location =
                                                                                                 BuiltIn
                                                                                             , kind =
                                                                                                 FunKind
                                                                                                   TypeKind
                                                                                                   TypeKind
                                                                                             })
                                                                                    , argument =
                                                                                        VariableType
                                                                                          (TypeVariable
                                                                                             { location =
                                                                                                 PropExpressionCursor
                                                                                                   (RecordFieldCursor
                                                                                                      (FieldName
                                                                                                         { unFieldName =
                                                                                                             "x"
                                                                                                         })
                                                                                                      (RowFieldExpression
                                                                                                         ExpressionCursor))
                                                                                             , prefix =
                                                                                                 ApplyPrefix
                                                                                             , index =
                                                                                                 2
                                                                                             , kind =
                                                                                                 TypeKind
                                                                                             })
                                                                                    , location =
                                                                                        BuiltIn
                                                                                    , kind =
                                                                                        TypeKind
                                                                                    })
                                                                           })
                                                                  })
                                                         , argument =
                                                             LiteralExpression
                                                               (NumberLiteral
                                                                  (Number
                                                                     { location =
                                                                         PropExpressionCursor
                                                                           (RecordFieldCursor
                                                                              (FieldName
                                                                                 { unFieldName =
                                                                                     "x"
                                                                                 })
                                                                              (RowFieldExpression
                                                                                 ExpressionCursor))
                                                                     , number =
                                                                         IntegerNumber 1
                                                                     , typ =
                                                                         ConstantType
                                                                           (TypeConstant
                                                                              { location =
                                                                                  PropExpressionCursor
                                                                                    (RecordFieldCursor
                                                                                       (FieldName
                                                                                          { unFieldName =
                                                                                              "x"
                                                                                          })
                                                                                       (RowFieldExpression
                                                                                          ExpressionCursor))
                                                                              , name =
                                                                                  IntegerTypeName
                                                                              })
                                                                     }))
                                                         , typ =
                                                             VariableType
                                                               (TypeVariable
                                                                  { location =
                                                                      PropExpressionCursor
                                                                        (RecordFieldCursor
                                                                           (FieldName
                                                                              { unFieldName =
                                                                                  "x"
                                                                              })
                                                                           (RowFieldExpression
                                                                              ExpressionCursor))
                                                                  , prefix = ApplyPrefix
                                                                  , index = 2
                                                                  , kind = TypeKind
                                                                  })
                                                         })
                                                , location =
                                                    PropExpressionCursor
                                                      (RecordFieldCursor
                                                         (FieldName {unFieldName = "x"})
                                                         TypeCursor)
                                                }
                                            ]
                                        , location =
                                            PropExpressionCursor ExpressionCursor
                                        , typ =
                                            RecordType
                                              (RowType
                                                 (TypeRow
                                                    { location =
                                                        PropExpressionCursor
                                                          ExpressionCursor
                                                    , typeVariable = Nothing
                                                    , fields =
                                                        [ Field
                                                            { location =
                                                                PropExpressionCursor
                                                                  (RecordFieldCursor
                                                                     (FieldName
                                                                        { unFieldName =
                                                                            "x"
                                                                        })
                                                                     TypeCursor)
                                                            , name =
                                                                FieldName
                                                                  {unFieldName = "x"}
                                                            , typ =
                                                                VariableType
                                                                  (TypeVariable
                                                                     { location =
                                                                         PropExpressionCursor
                                                                           (RecordFieldCursor
                                                                              (FieldName
                                                                                 { unFieldName =
                                                                                     "x"
                                                                                 })
                                                                              (RowFieldExpression
                                                                                 ExpressionCursor))
                                                                     , prefix =
                                                                         ApplyPrefix
                                                                     , index = 2
                                                                     , kind = TypeKind
                                                                     })
                                                            }
                                                        ]
                                                    }))
                                        })
                               , name = FieldName {unFieldName = "x"}
                               , typ =
                                   VariableType
                                     (TypeVariable
                                        { location =
                                            PropExpressionCursor
                                              (RecordFieldCursor
                                                 (FieldName {unFieldName = "x"})
                                                 (RowFieldExpression ExpressionCursor))
                                        , prefix = ApplyPrefix
                                        , index = 2
                                        , kind = TypeKind
                                        })
                               , location = ExpressionCursor
                               }))|]))
        it
          "123"
          (shouldReturnSatisfy
             (solveText' mempty "" "(123::Integer)")
             $(match [|Right
                         (IsSolved
                            { thing =
                                LiteralExpression
                                  (NumberLiteral
                                     (Number
                                        { location = ExpressionCursor
                                        , number = IntegerNumber 123
                                        , typ =
                                            ConstantType
                                              (TypeConstant
                                                 { location = ExpressionCursor
                                                 , name = IntegerTypeName
                                                 })
                                        }))
                            , mappings =
                                mempty
                            })|]))
        it
          "(x:x)123"
          (shouldReturnSatisfy
             (solveText' mempty "" "(x:x)(123::Integer)")
             $(match [|Right
                         (IsSolved
                            { thing =
                                ApplyExpression
                                  (Apply
                                     { location = ExpressionCursor
                                     , function =
                                         LambdaExpression
                                           (Lambda
                                              { location =
                                                  ApplyFuncCursor ExpressionCursor
                                              , param =
                                                  Param
                                                    { location =
                                                        ApplyFuncCursor LambdaParamCursor
                                                    , name = ()
                                                    , typ =
                                                        ConstantType
                                                          (TypeConstant
                                                             { location =
                                                                 ApplyArgCursor
                                                                   ExpressionCursor
                                                             , name = IntegerTypeName
                                                             })
                                                    }
                                              , body =
                                                  VariableExpression
                                                    (Variable
                                                       { location =
                                                           ApplyFuncCursor
                                                             (LambdaBodyCursor
                                                                ExpressionCursor)
                                                       , name =
                                                           DeBrujinIndex
                                                             (DeBrujinNesting 0)
                                                       , typ =
                                                           ConstantType
                                                             (TypeConstant
                                                                { location =
                                                                    ApplyArgCursor
                                                                      ExpressionCursor
                                                                , name = IntegerTypeName
                                                                })
                                                       })
                                              , typ =
                                                  ApplyType
                                                    (TypeApplication
                                                       { function =
                                                           ApplyType
                                                             (TypeApplication
                                                                { function =
                                                                    ConstantType
                                                                      (TypeConstant
                                                                         { location =
                                                                             ApplyFuncCursor
                                                                               ExpressionCursor
                                                                         , name =
                                                                             FunctionTypeName
                                                                         })
                                                                , argument =
                                                                    ConstantType
                                                                      (TypeConstant
                                                                         { location =
                                                                             ApplyArgCursor
                                                                               ExpressionCursor
                                                                         , name =
                                                                             IntegerTypeName
                                                                         })
                                                                , location =
                                                                    ApplyFuncCursor
                                                                      ExpressionCursor
                                                                , kind =
                                                                    FunKind
                                                                      TypeKind
                                                                      TypeKind
                                                                })
                                                       , argument =
                                                           ConstantType
                                                             (TypeConstant
                                                                { location =
                                                                    ApplyArgCursor
                                                                      ExpressionCursor
                                                                , name = IntegerTypeName
                                                                })
                                                       , location =
                                                           ApplyFuncCursor
                                                             ExpressionCursor
                                                       , kind = TypeKind
                                                       })
                                              })
                                     , argument =
                                         LiteralExpression
                                           (NumberLiteral
                                              (Number
                                                 { location =
                                                     ApplyArgCursor ExpressionCursor
                                                 , number = IntegerNumber 123
                                                 , typ =
                                                     ConstantType
                                                       (TypeConstant
                                                          { location =
                                                              ApplyArgCursor
                                                                ExpressionCursor
                                                          , name = IntegerTypeName
                                                          })
                                                 }))
                                     , typ =
                                         ConstantType
                                           (TypeConstant
                                              { location =
                                                  ApplyArgCursor ExpressionCursor
                                              , name = IntegerTypeName
                                              })
                                     })
                            , mappings =
                                mempty
                            })|])))
  erroneous

erroneous :: SpecWith ()
erroneous =
  describe
    "Erroneous"
  (do
     it "@prim:rich_doc([@prim:rich_paragraph([@prim:rich_text(\"Hello!\")])])"
        (shouldReturn
           (solveText' mempty "" "@prim:rich_doc([@prim:rich_text(\"Hello!\")])")
           (Left (SolverError (TypeMismatch (EqualityConstraint {type1 = ConstantType (TypeConstant {location = ApplyFuncCursor ExpressionCursor, name = RichBlockTypeName}), type2 = VariableType (TypeVariable {location = ApplyArgCursor ExpressionCursor, prefix = ArrayElementPrefix, index = 0, kind = TypeKind}), location = BuiltIn})))))
     it
       "{x:1}.y"
       (shouldReturn
          (solveText' mempty "" "{x:1}.y")
          (Left (SolverError (RowMismatch (TypeRow {location = ExpressionCursor, typeVariable = Just (TypeVariable {location = ExpressionCursor, prefix = RowVarPrefix, index = 0, kind = RowKind}), fields = [Field {location = ExpressionCursor, name = FieldName {unFieldName = "y"}, typ = VariableType (TypeVariable {location = ExpressionCursor, prefix = FieldTypePrefix, index = 3, kind = TypeKind})}]}) (TypeRow {location = PropExpressionCursor ExpressionCursor, typeVariable = Nothing, fields = [Field {location = PropExpressionCursor (RecordFieldCursor (FieldName {unFieldName = "x"}) TypeCursor), name = FieldName {unFieldName = "x"}, typ = VariableType (TypeVariable {location = PropExpressionCursor (RecordFieldCursor (FieldName {unFieldName = "x"}) (RowFieldExpression ExpressionCursor)), prefix = ApplyPrefix, index = 2, kind = TypeKind})}]}) ))))
     it
       "[{x:1},{y:1}]"
       (shouldReturn
          (fmap (fmap Inflex.Solver.thing) (solveText' mempty "" "[{x:1},{y:1}]"))
          (Left (SolverError (RowMismatch (TypeRow {location = ArrayElementCursor 1 ExpressionCursor, typeVariable = Nothing, fields = [Field {location = ArrayElementCursor 1 (RecordFieldCursor (FieldName {unFieldName = "y"}) TypeCursor), name = FieldName {unFieldName = "y"}, typ = VariableType (TypeVariable {location = ArrayElementCursor 1 (RecordFieldCursor (FieldName {unFieldName = "y"}) (RowFieldExpression ExpressionCursor)), prefix = ApplyPrefix, index = 4, kind = TypeKind})}]}) (TypeRow {location = ArrayElementCursor 0 ExpressionCursor, typeVariable = Nothing, fields = [Field {location = ArrayElementCursor 0 (RecordFieldCursor (FieldName {unFieldName = "x"}) TypeCursor), name = FieldName {unFieldName = "x"}, typ = VariableType (TypeVariable {location = ArrayElementCursor 0 (RecordFieldCursor (FieldName {unFieldName = "x"}) (RowFieldExpression ExpressionCursor)), prefix = ApplyPrefix, index = 2, kind = TypeKind})}]})))))
     it
       "[{x:1},{y:{}]"
       (shouldReturn
          (fmap (fmap Inflex.Solver.thing) (solveText' mempty "" "[{x:1},{y:{a:2}}]"))
          (Left (SolverError (RowMismatch (TypeRow {location = ArrayElementCursor 1 ExpressionCursor, typeVariable = Nothing, fields = [Field {location = ArrayElementCursor 1 (RecordFieldCursor (FieldName {unFieldName = "y"}) TypeCursor), name = FieldName {unFieldName = "y"}, typ = RecordType (RowType (TypeRow {location = ArrayElementCursor 1 (RecordFieldCursor (FieldName {unFieldName = "y"}) (RowFieldExpression ExpressionCursor)), typeVariable = Nothing, fields = [Field {location = ArrayElementCursor 1 (RecordFieldCursor (FieldName {unFieldName = "y"}) (RowFieldExpression (RecordFieldCursor (FieldName {unFieldName = "a"}) TypeCursor))), name = FieldName {unFieldName = "a"}, typ = VariableType (TypeVariable {location = ArrayElementCursor 1 (RecordFieldCursor (FieldName {unFieldName = "y"}) (RowFieldExpression (RecordFieldCursor (FieldName {unFieldName = "a"}) (RowFieldExpression ExpressionCursor)))), prefix = ApplyPrefix, index = 4, kind = TypeKind})}]}))}]}) (TypeRow {location = ArrayElementCursor 0 ExpressionCursor, typeVariable = Nothing, fields = [Field {location = ArrayElementCursor 0 (RecordFieldCursor (FieldName {unFieldName = "x"}) TypeCursor), name = FieldName {unFieldName = "x"}, typ = VariableType (TypeVariable {location = ArrayElementCursor 0 (RecordFieldCursor (FieldName {unFieldName = "x"}) (RowFieldExpression ExpressionCursor)), prefix = ApplyPrefix, index = 2, kind = TypeKind})}]}))))))

--------------------------------------------------------------------------------
-- Fine-grained tests

fineGrained :: Spec
fineGrained = do
  describe
    "Successful"
    (do it "a ~ a" (shouldReturn (unifyConstraints' [a .~ a]) (pure []))
        it
          "Integer ~ Integer"
          (shouldReturn (unifyConstraints' [_Integer .~ _Integer]) (pure []))
        it
          "a ~ b"
          (shouldReturn (unifyConstraints' [a .~ b]) (pure [a' .+-> b]))
        it
          "a ~ Integer"
          (shouldReturn
             (unifyConstraints' [a .~ _Integer])
             (pure [a' .+-> _Integer]))
        it
          "F a b ~ F Text a"
          (shouldReturn
             (unifyConstraints' [_F a b .~ _F _Text a])
             (pure [a' .+-> _Text, b' .+-> _Text]))
        it
          "F a Text ~ F Text a"
          (shouldReturn
             (unifyConstraints' [_F a _Text .~ _F _Text a])
             (pure [a' .+-> _Text]))
        it
          "F a Text ~ F Integer b"
          (shouldReturn
             (unifyConstraints' [_F a _Text .~ _F _Integer b])
             (pure [a' .+-> _Integer, b' .+-> _Text]))
        it
          "F a a ~ F (Option b) (Option Integer)"
          (shouldReturn
             (unifyConstraints' [_F a a .~ _F (_Option b) (_Option _Integer)])
             (pure [a' .+-> _Option _Integer, b' .+-> _Integer]))
        it
          "(t ~ F a a, F a a ~ F (Option b) (Option Integer)) => t"
          (shouldReturn
             (unifyAndSubstitute'
                [t .~ _F a a, _F a a .~ _F (_Option b) (_Option _Integer)]
                t)
             (pure (solveType mempty (_F (_Option _Integer) (_Option _Integer))))))
  describe
    "Failing"
    (do it
          "Occurs check: F a b ~ a"
          (shouldReturn
             (unifyConstraints' [_F a b .~ a])
             (Left (OccursCheckFail a' (_F a b))))
        it
          "Kind mismatch: F a ~ b"
          (shouldReturn
             (unifyConstraints' [_F_partial a .~ b])
             (Left (KindMismatch b' (_F_partial a))))
        it
          "Constant mismatch: Integer ~ Text"
          (shouldReturn
             (unifyConstraints' [_Integer .~ _Text])
             (Left (TypeMismatch (_Integer .~ _Text))))
        it
          "Type mismatch: F a a ~ F (Option Text) (Option Integer)"
          (shouldReturn
             (unifyConstraints'
                [_F a a .~ _F (_Option _Text) (_Option _Integer)])
             (Left (TypeMismatch (_Text .~ _Integer)))))

--------------------------------------------------------------------------------
-- Type variables

a' :: TypeVariable Generated
a' =
  TypeVariable
    {location = ExpressionCursor, prefix = IntegerPrefix, index = 0, kind = TypeKind}

b' :: TypeVariable Generated
b' =
  TypeVariable
    {location = ExpressionCursor, prefix = IntegerPrefix, index = 1, kind = TypeKind}

c' :: TypeVariable Generated
c' =
  TypeVariable
    {location = ExpressionCursor, prefix = IntegerPrefix, index = 2, kind = TypeKind}

--------------------------------------------------------------------------------
-- Types of the variables

t :: Type Generated
t =
  VariableType
    TypeVariable
      {location = ExpressionCursor, prefix = IntegerPrefix, index = 3, kind = TypeKind}

a :: Type Generated
a = VariableType a'

b :: Type Generated
b = VariableType b'

c :: Type Generated
c = VariableType c'

--------------------------------------------------------------------------------
-- Type constructors

_Integer :: Type Generated
_Integer =
  ConstantType
    TypeConstant {location = ExpressionCursor, name = IntegerTypeName}

_Text :: Type Generated
_Text =
  ConstantType
    TypeConstant {location = ExpressionCursor, name = TextTypeName}

_F :: Type Generated -> Type Generated -> Type Generated
_F x1 x2 =
  ApplyType
    TypeApplication
      { location = ExpressionCursor
      , function =
          ApplyType
            TypeApplication
              { location = ExpressionCursor
              , function =
                  ConstantType
                    TypeConstant
                      {location = ExpressionCursor, name = FunctionTypeName}
              , argument = x1
              , kind = FunKind TypeKind TypeKind
              }
      , argument = x2
      , kind = TypeKind
      }

_F_partial :: Type Generated -> Type Generated
_F_partial x1 =
  ApplyType
      TypeApplication
        { location = ExpressionCursor
        , function =
            ConstantType
              TypeConstant
                {location = ExpressionCursor, name = FunctionTypeName}
        , argument = x1
        , kind = FunKind TypeKind TypeKind
        }

_Option :: Type Generated -> Type Generated
_Option x1 =
  ApplyType
    TypeApplication
      { location = ExpressionCursor
      , function =
          ConstantType
            TypeConstant
              {location = ExpressionCursor, name = OptionTypeName}
      , argument = x1
      , kind = TypeKind
      }

--------------------------------------------------------------------------------
-- Operators for easier reading

(.~) :: Type Generated -> Type Generated -> EqualityConstraint
(.~) x y =
  EqualityConstraint {location = ExpressionCursor, type1 = x, type2 = y}

(.+->) :: TypeVariable Generated -> Type Generated -> Substitution
(.+->) x y = Substitution {before = x, after = y}

--------------------------------------------------------------------------------
-- Coarse grained

variants :: SpecWith ()
variants = do
  it
    "[#ok(1),#fail]"
    (shouldReturnSatisfy (fmap (fmap Inflex.Solver.thing) (solveText' mempty "" "[#ok(1),#fail]"))
              $(match [|Right (ArrayExpression (Array {form = (), expressions = [VariantExpression (Variant {location = ArrayElementCursor 0 ExpressionCursor, typ = VariantType (RowType (TypeRow {location = ArrayElementCursor 0 ExpressionCursor, typeVariable = Just (TypeVariable {location = ArrayElementCursor 1 ExpressionCursor, prefix = SolverGeneratedPrefix RowUnifyPrefix, index = 0, kind = RowKind}), fields = [Field {location = ArrayElementCursor 1 ExpressionCursor, name = FieldName {unFieldName = "fail"}, typ = RecordType (RowType (TypeRow {location = ArrayElementCursor 1 ExpressionCursor, typeVariable = Nothing, fields = []}))},Field {location = ArrayElementCursor 0 ExpressionCursor, name = FieldName {unFieldName = "ok"}, typ = VariableType (TypeVariable {location = ArrayElementCursor 0 (VariantElementCursor ExpressionCursor), prefix = ApplyPrefix, index = 3, kind = TypeKind})}]})), tag = TagName {unTagName = "ok"}, argument = Just (ApplyExpression (Apply {location = BuiltIn, function = GlobalExpression (Global {location = BuiltIn, name = FromIntegerGlobal, scheme = SolvedScheme (Scheme {location = BuiltIn, constraints = [ClassConstraint {className = FromIntegerClassName, typ = VariableType (TypeVariable {location = ArrayElementCursor 0 (VariantElementCursor ExpressionCursor), prefix = ApplyPrefix, index = 3, kind = TypeKind}) :| [], location = BuiltIn}], typ = ApplyType (TypeApplication {function = ApplyType (TypeApplication {function = ConstantType (TypeConstant {location = BuiltIn, name = FunctionTypeName}), argument = ConstantType (TypeConstant {location = BuiltIn, name = IntegerTypeName}), location = BuiltIn, kind = FunKind TypeKind TypeKind}), argument = VariableType (TypeVariable {location = ArrayElementCursor 0 (VariantElementCursor ExpressionCursor), prefix = ApplyPrefix, index = 3, kind = TypeKind}), location = BuiltIn, kind = TypeKind})})}), argument = LiteralExpression (NumberLiteral (Number {location = ArrayElementCursor 0 (VariantElementCursor ExpressionCursor), number = IntegerNumber 1, typ = ConstantType (TypeConstant {location = ArrayElementCursor 0 (VariantElementCursor ExpressionCursor), name = IntegerTypeName})})), typ = VariableType (TypeVariable {location = ArrayElementCursor 0 (VariantElementCursor ExpressionCursor), prefix = ApplyPrefix, index = 3, kind = TypeKind})}))}),VariantExpression (Variant {location = ArrayElementCursor 1 ExpressionCursor, typ = VariantType (RowType (TypeRow {location = ArrayElementCursor 1 ExpressionCursor, typeVariable = Just (TypeVariable {location = ArrayElementCursor 1 ExpressionCursor, prefix = SolverGeneratedPrefix RowUnifyPrefix, index = 0, kind = RowKind}), fields = [Field {location = ArrayElementCursor 0 ExpressionCursor, name = FieldName {unFieldName = "ok"}, typ = VariableType (TypeVariable {location = ArrayElementCursor 0 (VariantElementCursor ExpressionCursor), prefix = ApplyPrefix, index = 3, kind = TypeKind})},Field {location = ArrayElementCursor 1 ExpressionCursor, name = FieldName {unFieldName = "fail"}, typ = RecordType (RowType (TypeRow {location = ArrayElementCursor 1 ExpressionCursor, typeVariable = Nothing, fields = []}))}]})), tag = TagName {unTagName = "fail"}, argument = Nothing})], typ = ArrayType (VariantType (RowType (TypeRow {location = ArrayElementCursor 0 ExpressionCursor, typeVariable = Just (TypeVariable {location = ArrayElementCursor 1 ExpressionCursor, prefix = SolverGeneratedPrefix RowUnifyPrefix, index = 0, kind = RowKind}), fields = [Field {location = ArrayElementCursor 1 ExpressionCursor, name = FieldName {unFieldName = "fail"}, typ = RecordType (RowType (TypeRow {location = ArrayElementCursor 1 ExpressionCursor, typeVariable = Nothing, fields = []}))},Field {location = ArrayElementCursor 0 ExpressionCursor, name = FieldName {unFieldName = "ok"}, typ = VariableType (TypeVariable {location = ArrayElementCursor 0 (VariantElementCursor ExpressionCursor), prefix = ApplyPrefix, index = 3, kind = TypeKind})}]}))), location = ExpressionCursor}))|]))
  it
    "if (#a) { #b: {} }"
    (shouldReturn (fmap (fmap Inflex.Solver.thing) (solveText' mempty "" "if (#a) { #b: {} }"))
              (Left (SolverError (RowMismatch (TypeRow {location = ExpressionCursor, typeVariable = Just (TypeVariable {location = ExpressionCursor, prefix = VariantRowVarPrefix, index = 0, kind = RowKind}), fields = [Field {location = ExpressionCursor, name = FieldName {unFieldName = "a"}, typ = RecordType (RowType (TypeRow {location = ExpressionCursor, typeVariable = Nothing, fields = []}))}]}) (TypeRow {location = ExpressionCursor, typeVariable = Nothing, fields = [Field {location = ExpressionCursor, name = FieldName {unFieldName = "b"}, typ = RecordType (RowType (TypeRow {location = ExpressionCursor, typeVariable = Nothing, fields = []}))}]})))))
  it
      "if (#a) { #b: {}, wild: {} }"
      (shouldReturn (fmap (fmap Inflex.Solver.thing) (solveText' mempty "" "if (#a) { #b: {}, wild: {} }"))
                (Right (CaseExpression (Case {location = ExpressionCursor, typ = RecordType (RowType (TypeRow {location = ExpressionCursor, typeVariable = Nothing, fields = []})), scrutinee = VariantExpression (Variant {location = ExpressionCursor, typ = VariantType (RowType (TypeRow {location = ExpressionCursor, typeVariable = Just (TypeVariable {location = ExpressionCursor, prefix = SolverGeneratedPrefix RowUnifyPrefix, index = 1, kind = RowKind}), fields = [Field {location = ExpressionCursor, name = FieldName {unFieldName = "b"}, typ = RecordType (RowType (TypeRow {location = ExpressionCursor, typeVariable = Nothing, fields = []}))},Field {location = ExpressionCursor, name = FieldName {unFieldName = "a"}, typ = RecordType (RowType (TypeRow {location = ExpressionCursor, typeVariable = Nothing, fields = []}))}]})), tag = TagName {unTagName = "a"}, argument = Nothing}), alternatives = Alternative {location = ExpressionCursor, pattern' = VariantPattern (VariantP {location = ExpressionCursor, tag = TagName {unTagName = "b"}, argument = Nothing}), expression = RecordExpression (Record {fields = [], location = ExpressionCursor, typ = RecordType (RowType (TypeRow {location = ExpressionCursor, typeVariable = Nothing, fields = []}))})} :| [Alternative {location = ExpressionCursor, pattern' = ParamPattern (Param {location = LambdaParamCursor, name = (), typ = VariantType (RowType (TypeRow {location = ExpressionCursor, typeVariable = Just (TypeVariable {location = ExpressionCursor, prefix = SolverGeneratedPrefix RowUnifyPrefix, index = 1, kind = RowKind}), fields = [Field {location = ExpressionCursor, name = FieldName {unFieldName = "b"}, typ = RecordType (RowType (TypeRow {location = ExpressionCursor, typeVariable = Nothing, fields = []}))},Field {location = ExpressionCursor, name = FieldName {unFieldName = "a"}, typ = RecordType (RowType (TypeRow {location = ExpressionCursor, typeVariable = Nothing, fields = []}))}]}))}), expression = RecordExpression (Record {fields = [], location = ExpressionCursor, typ = RecordType (RowType (TypeRow {location = ExpressionCursor, typeVariable = Nothing, fields = []}))})}]}))))


arrays :: SpecWith ()
arrays = do
  it
    "[[1],[2]]"
    (shouldReturnSatisfy
       (fmap (fmap Inflex.Solver.thing) (solveText' mempty "" "[[1],[2]]"))
       $(match [|Right (ArrayExpression (Array {form = (), expressions = [ArrayExpression (Array {form = (), expressions = [ApplyExpression (Apply {location = BuiltIn, function = GlobalExpression (Global {location = BuiltIn, name = FromIntegerGlobal, scheme = SolvedScheme (Scheme {location = BuiltIn, constraints = [ClassConstraint {className = FromIntegerClassName, typ = VariableType (TypeVariable {location = ArrayElementCursor 0 ExpressionCursor, prefix = ArrayElementPrefix, index = 1, kind = TypeKind}) :| [], location = BuiltIn}], typ = ApplyType (TypeApplication {function = ApplyType (TypeApplication {function = ConstantType (TypeConstant {location = BuiltIn, name = FunctionTypeName}), argument = ConstantType (TypeConstant {location = BuiltIn, name = IntegerTypeName}), location = BuiltIn, kind = FunKind TypeKind TypeKind}), argument = VariableType (TypeVariable {location = ArrayElementCursor 0 ExpressionCursor, prefix = ArrayElementPrefix, index = 1, kind = TypeKind}), location = BuiltIn, kind = TypeKind})})}), argument = LiteralExpression (NumberLiteral (Number {location = ArrayElementCursor 0 (ArrayElementCursor 0 ExpressionCursor), number = IntegerNumber 1, typ = ConstantType (TypeConstant {location = ArrayElementCursor 0 (ArrayElementCursor 0 ExpressionCursor), name = IntegerTypeName})})), typ = VariableType (TypeVariable {location = ArrayElementCursor 0 ExpressionCursor, prefix = ArrayElementPrefix, index = 1, kind = TypeKind})})], typ = ArrayType (VariableType (TypeVariable {location = ArrayElementCursor 0 ExpressionCursor, prefix = ArrayElementPrefix, index = 1, kind = TypeKind})), location = ArrayElementCursor 0 ExpressionCursor}),ArrayExpression (Array {form = (), expressions = [ApplyExpression (Apply {location = BuiltIn, function = GlobalExpression (Global {location = BuiltIn, name = FromIntegerGlobal, scheme = SolvedScheme (Scheme {location = BuiltIn, constraints = [ClassConstraint {className = FromIntegerClassName, typ = VariableType (TypeVariable {location = ArrayElementCursor 0 ExpressionCursor, prefix = ArrayElementPrefix, index = 1, kind = TypeKind}) :| [], location = BuiltIn}], typ = ApplyType (TypeApplication {function = ApplyType (TypeApplication {function = ConstantType (TypeConstant {location = BuiltIn, name = FunctionTypeName}), argument = ConstantType (TypeConstant {location = BuiltIn, name = IntegerTypeName}), location = BuiltIn, kind = FunKind TypeKind TypeKind}), argument = VariableType (TypeVariable {location = ArrayElementCursor 0 ExpressionCursor, prefix = ArrayElementPrefix, index = 1, kind = TypeKind}), location = BuiltIn, kind = TypeKind})})}), argument = LiteralExpression (NumberLiteral (Number {location = ArrayElementCursor 1 (ArrayElementCursor 0 ExpressionCursor), number = IntegerNumber 2, typ = ConstantType (TypeConstant {location = ArrayElementCursor 1 (ArrayElementCursor 0 ExpressionCursor), name = IntegerTypeName})})), typ = VariableType (TypeVariable {location = ArrayElementCursor 0 ExpressionCursor, prefix = ArrayElementPrefix, index = 1, kind = TypeKind})})], typ = ArrayType (VariableType (TypeVariable {location = ArrayElementCursor 0 ExpressionCursor, prefix = ArrayElementPrefix, index = 1, kind = TypeKind})), location = ArrayElementCursor 1 ExpressionCursor})], typ = ArrayType (ArrayType (VariableType (TypeVariable {location = ArrayElementCursor 0 ExpressionCursor, prefix = ArrayElementPrefix, index = 1, kind = TypeKind}))), location = ExpressionCursor}))|]))
  arrayHoles

arrayHoles :: Spec
arrayHoles = do
  it
    "[] :: [_]"
    (shouldReturn
       (fmap (fmap Inflex.Solver.thing) (solveText' mempty "" "[] :: [_]"))
       (Right
          (ArrayExpression
             (Array
                { form = ()
                , expressions = []
                , typ =
                    ArrayType
                      (VariableType
                         (TypeVariable
                            { location = ExpressionCursor
                            , prefix = ArrayElementPrefix
                            , index = 0
                            , kind = TypeKind
                            }))
                , location = ExpressionCursor
                }))))
  it
    "[] :: [{a:_}]"
    (shouldReturn
       (fmap (fmap Inflex.Solver.thing) (solveText' mempty "" "[] :: [{a:_}]"))
       (Right
          (ArrayExpression
             (Array
                { form = ()
                , expressions = []
                , typ =
                    ArrayType
                      (RecordType
                         (RowType
                            (TypeRow
                               { location = SignatureCursor TypeCursor
                               , typeVariable = Nothing
                               , fields =
                                   [ Field
                                       { location =
                                           SignatureCursor
                                             (RowFieldCursor TypeCursor)
                                       , name = FieldName {unFieldName = "a"}
                                       , typ =
                                           VariableType
                                             (TypeVariable
                                                { location =
                                                    SignatureCursor
                                                      (RowFieldCursor
                                                         (RowFieldType
                                                            LambdaParamCursor))
                                                , prefix = FreshPrefix
                                                , index = 1
                                                , kind = TypeKind
                                                })
                                       }
                                   ]
                               })))
                , location = ExpressionCursor
                }))))
  it
    "[] :: [{a,b}]"
    (shouldReturn
       (fmap (fmap Inflex.Solver.thing) (solveText' mempty "" "[] :: [{a,b}]"))
       (Right
          (ArrayExpression
             (Array
                { form = ()
                , expressions = []
                , typ =
                    ArrayType
                      (RecordType
                         (RowType
                            (TypeRow
                               { location = SignatureCursor TypeCursor
                               , typeVariable = Nothing
                               , fields =
                                   [ Field
                                       { location =
                                           SignatureCursor
                                             (RowFieldCursor TypeCursor)
                                       , name = FieldName {unFieldName = "a"}
                                       , typ =
                                           VariableType
                                             (TypeVariable
                                                { location =
                                                    SignatureCursor
                                                      (RowFieldCursor
                                                         (RowFieldType
                                                            LambdaParamCursor))
                                                , prefix = FreshPrefix
                                                , index = 1
                                                , kind = TypeKind
                                                })
                                       }
                                   , Field
                                       { location =
                                           SignatureCursor
                                             (RowFieldCursor TypeCursor)
                                       , name = FieldName {unFieldName = "b"}
                                       , typ =
                                           VariableType
                                             (TypeVariable
                                                { location =
                                                    SignatureCursor
                                                      (RowFieldCursor
                                                         (RowFieldType
                                                            LambdaParamCursor))
                                                , prefix = FreshPrefix
                                                , index = 2
                                                , kind = TypeKind
                                                })
                                       }
                                   ]
                               })))
                , location = ExpressionCursor
                }))))
  it
    "[] :: [{a,b:{x}]"
    (shouldReturn
       (fmap
          (fmap Inflex.Solver.thing)
          (solveText' mempty "" "[] :: [{a,b:{x}}]"))
       (Right
          (ArrayExpression
             (Array
                { form = ()
                , expressions = []
                , typ =
                    ArrayType
                      (RecordType
                         (RowType
                            (TypeRow
                               { location = SignatureCursor TypeCursor
                               , typeVariable = Nothing
                               , fields =
                                   [ Field
                                       { location =
                                           SignatureCursor
                                             (RowFieldCursor TypeCursor)
                                       , name = FieldName {unFieldName = "a"}
                                       , typ =
                                           VariableType
                                             (TypeVariable
                                                { location =
                                                    SignatureCursor
                                                      (RowFieldCursor
                                                         (RowFieldType
                                                            LambdaParamCursor))
                                                , prefix = FreshPrefix
                                                , index = 1
                                                , kind = TypeKind
                                                })
                                       }
                                   , Field
                                       { location =
                                           SignatureCursor
                                             (RowFieldCursor TypeCursor)
                                       , name = FieldName {unFieldName = "b"}
                                       , typ =
                                           RecordType
                                             (RowType
                                                (TypeRow
                                                   { location =
                                                       SignatureCursor
                                                         (RowFieldCursor
                                                            (RowFieldType
                                                               TypeCursor))
                                                   , typeVariable = Nothing
                                                   , fields =
                                                       [ Field
                                                           { location =
                                                               SignatureCursor
                                                                 (RowFieldCursor
                                                                    (RowFieldType
                                                                       (RowFieldCursor
                                                                          TypeCursor)))
                                                           , name =
                                                               FieldName
                                                                 { unFieldName =
                                                                     "x"
                                                                 }
                                                           , typ =
                                                               VariableType
                                                                 (TypeVariable
                                                                    { location =
                                                                        SignatureCursor
                                                                          (RowFieldCursor
                                                                             (RowFieldType
                                                                                (RowFieldCursor
                                                                                   (RowFieldType
                                                                                      LambdaParamCursor))))
                                                                    , prefix =
                                                                        FreshPrefix
                                                                    , index = 2
                                                                    , kind =
                                                                        TypeKind
                                                                    })
                                                           }
                                                       ]
                                                   }))
                                       }
                                   ]
                               })))
                , location = ExpressionCursor
                }))))
  it
    "Regression test for row inference"
    (do (shouldReturn
           (fmap
              (fmap Inflex.Solver.thing)
              (do !v <- solveText' mempty "" "if (_){#foo(e):e.t}"
                  pure v))
           (Right
              (CaseExpression
                 (Case
                    { location = ExpressionCursor
                    , typ =
                        VariableType
                          (TypeVariable
                             { location = ExpressionCursor
                             , prefix = FieldTypePrefix
                             , index = 4
                             , kind = TypeKind
                             })
                    , scrutinee =
                        HoleExpression
                          (Hole
                             { location = TypeCursor
                             , typ =
                                 VariantType
                                   (RowType
                                      (TypeRow
                                         { location = ExpressionCursor
                                         , typeVariable = Nothing
                                         , fields =
                                             [ Field
                                                 { location = ExpressionCursor
                                                 , name =
                                                     FieldName
                                                       {unFieldName = "foo"}
                                                 , typ =
                                                     RecordType
                                                       (RowType
                                                          (TypeRow
                                                             { location =
                                                                 ExpressionCursor
                                                             , typeVariable =
                                                                 Just
                                                                   (TypeVariable
                                                                      { location =
                                                                          ExpressionCursor
                                                                      , prefix =
                                                                          RowVarPrefix
                                                                      , index =
                                                                          2
                                                                      , kind =
                                                                          RowKind
                                                                      })
                                                             , fields =
                                                                 [ Field
                                                                     { location =
                                                                         ExpressionCursor
                                                                     , name =
                                                                         FieldName
                                                                           { unFieldName =
                                                                               "t"
                                                                           }
                                                                     , typ =
                                                                         VariableType
                                                                           (TypeVariable
                                                                              { location =
                                                                                  ExpressionCursor
                                                                              , prefix =
                                                                                  FieldTypePrefix
                                                                              , index =
                                                                                  4
                                                                              , kind =
                                                                                  TypeKind
                                                                              })
                                                                     }
                                                                 ]
                                                             }))
                                                 }
                                             ]
                                         }))
                             })
                    , alternatives =
                        Alternative
                          { location = ExpressionCursor
                          , pattern' =
                              VariantPattern
                                (VariantP
                                   { location = ExpressionCursor
                                   , tag = TagName {unTagName = "foo"}
                                   , argument =
                                       Just
                                         (Param
                                            { location = LambdaParamCursor
                                            , name = ()
                                            , typ =
                                                RecordType
                                                  (RowType
                                                     (TypeRow
                                                        { location =
                                                            ExpressionCursor
                                                        , typeVariable =
                                                            Just
                                                              (TypeVariable
                                                                 { location =
                                                                     ExpressionCursor
                                                                 , prefix =
                                                                     RowVarPrefix
                                                                 , index = 2
                                                                 , kind =
                                                                     RowKind
                                                                 })
                                                        , fields =
                                                            [ Field
                                                                { location =
                                                                    ExpressionCursor
                                                                , name =
                                                                    FieldName
                                                                      { unFieldName =
                                                                          "t"
                                                                      }
                                                                , typ =
                                                                    VariableType
                                                                      (TypeVariable
                                                                         { location =
                                                                             ExpressionCursor
                                                                         , prefix =
                                                                             FieldTypePrefix
                                                                         , index =
                                                                             4
                                                                         , kind =
                                                                             TypeKind
                                                                         })
                                                                }
                                                            ]
                                                        }))
                                            })
                                   })
                          , expression =
                              PropExpression
                                (Prop
                                   { expression =
                                       VariableExpression
                                         (Variable
                                            { location =
                                                PropExpressionCursor
                                                  ExpressionCursor
                                            , name =
                                                DeBrujinIndex
                                                  (DeBrujinNesting 0)
                                            , typ =
                                                RecordType
                                                  (RowType
                                                     (TypeRow
                                                        { location =
                                                            ExpressionCursor
                                                        , typeVariable =
                                                            Just
                                                              (TypeVariable
                                                                 { location =
                                                                     ExpressionCursor
                                                                 , prefix =
                                                                     RowVarPrefix
                                                                 , index = 2
                                                                 , kind =
                                                                     RowKind
                                                                 })
                                                        , fields =
                                                            [ Field
                                                                { location =
                                                                    ExpressionCursor
                                                                , name =
                                                                    FieldName
                                                                      { unFieldName =
                                                                          "t"
                                                                      }
                                                                , typ =
                                                                    VariableType
                                                                      (TypeVariable
                                                                         { location =
                                                                             ExpressionCursor
                                                                         , prefix =
                                                                             FieldTypePrefix
                                                                         , index =
                                                                             4
                                                                         , kind =
                                                                             TypeKind
                                                                         })
                                                                }
                                                            ]
                                                        }))
                                            })
                                   , name = FieldName {unFieldName = "t"}
                                   , typ =
                                       VariableType
                                         (TypeVariable
                                            { location = ExpressionCursor
                                            , prefix = FieldTypePrefix
                                            , index = 4
                                            , kind = TypeKind
                                            })
                                   , location = ExpressionCursor
                                   })
                          } :|
                        []
                    })))))

regression :: SpecWith ()
regression =
  it
    "[#foo, #bar, #zot(\"hisdsfd\")]"
    (shouldReturnSatisfy
       (fmap
          (fmap Inflex.Solver.thing)
          (solveText' mempty "" "[#foo, #bar, #zot(\"hisdsfd\")]"))
       $(match
           [|Right
               (ArrayExpression
                  (Array
                     { expressions =
                         [ VariantExpression
                             (Variant
                                { typ =
                                    VariantType
                                      (RowType
                                         (TypeRow
                                            { typeVariable = Just _
                                            , fields =
                                                [ Field
                                                    { name =
                                                        FieldName
                                                          {unFieldName = "zot"}
                                                    }
                                                , Field
                                                    { name =
                                                        FieldName
                                                          {unFieldName = "bar"}
                                                    }
                                                , Field
                                                    { name =
                                                        FieldName
                                                          {unFieldName = "foo"}
                                                    }
                                                ]
                                            }))
                                })
                         , _
                         , _
                         ]
                     , typ =
                         ArrayType
                           (VariantType
                              (RowType
                                 (TypeRow
                                    { typeVariable = Just _
                                    , fields =
                                        [ Field
                                            { name =
                                                FieldName {unFieldName = "zot"}
                                            }
                                        , Field
                                            { name =
                                                FieldName {unFieldName = "bar"}
                                            }
                                        , Field
                                            { name =
                                                FieldName {unFieldName = "foo"}
                                            }
                                        ]
                                    })))
                     }))|]))
