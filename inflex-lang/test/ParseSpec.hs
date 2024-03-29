{-# LANGUAGE GADTs, OverloadedLists #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Test the parser.

module ParseSpec where

import           Data.Bifunctor
import           Data.Decimal
import qualified Data.Text as T
import qualified Data.Vector as V
import           Inflex.Instances ()
import           Inflex.Lexer
import           Inflex.Parser
import qualified Inflex.Parser2 as Parser2
import           Inflex.Types
import           Match
import           Test.Hspec

spec :: Spec
spec = do

  strings
  variants
  sigs
  types
  literals
  globals
  lambda
  apply
  records
  {-implicitcalls-}
  dotcalls
  {-early-}
  describe "Operators" ops
  parser2
  rich

ops :: Spec
ops = do
  it
    "x+y"
    (shouldBe
       (parseText "" "x+y")
       (Right
          (InfixExpression
             (Infix
                { location =
                    SourceLocation
                      { start = SourcePos {line = 1, column = 1, name = ""}
                      , end = SourcePos {line = 1, column = 4, name = ""}
                      }
                , global =
                    Global
                      { location =
                          SourceLocation
                            { start =
                                SourcePos {line = 1, column = 1, name = ""}
                            , end = SourcePos {line = 1, column = 4, name = ""}
                            }
                      , name = ParsedTextName "+"
                      , scheme = ParsedScheme
                      }
                , left =
                    VariableExpression
                      (Variable
                         { location =
                             SourceLocation
                               { start =
                                   SourcePos {line = 1, column = 1, name = ""}
                               , end =
                                   SourcePos {line = 1, column = 2, name = ""}
                               }
                         , name = "x"
                         , typ = Nothing
                         })
                , right =
                    VariableExpression
                      (Variable
                         { location =
                             SourceLocation
                               { start =
                                   SourcePos {line = 1, column = 3, name = ""}
                               , end =
                                   SourcePos {line = 1, column = 4, name = ""}
                               }
                         , name = "y"
                         , typ = Nothing
                         })
                , typ = Nothing
                }))))
  it
    "x+y-z*y/2"
    (shouldBe
       (parseText "" "x+y-z*y/2")
       (Right
          (InfixExpression
             (Infix
                { location =
                    SourceLocation
                      { start = SourcePos {line = 1, column = 1, name = ""}
                      , end = SourcePos {line = 1, column = 10, name = ""}
                      }
                , global =
                    Global
                      { location =
                          SourceLocation
                            { start =
                                SourcePos {line = 1, column = 1, name = ""}
                            , end = SourcePos {line = 1, column = 10, name = ""}
                            }
                      , name = ParsedTextName "-"
                      , scheme = ParsedScheme
                      }
                , left =
                    InfixExpression
                      (Infix
                         { location =
                             SourceLocation
                               { start =
                                   SourcePos {line = 1, column = 1, name = ""}
                               , end =
                                   SourcePos {line = 1, column = 4, name = ""}
                               }
                         , global =
                             Global
                               { location =
                                   SourceLocation
                                     { start =
                                         SourcePos
                                           {line = 1, column = 1, name = ""}
                                     , end =
                                         SourcePos
                                           {line = 1, column = 4, name = ""}
                                     }
                               , name = ParsedTextName "+"
                               , scheme = ParsedScheme
                               }
                         , left =
                             VariableExpression
                               (Variable
                                  { location =
                                      SourceLocation
                                        { start =
                                            SourcePos
                                              {line = 1, column = 1, name = ""}
                                        , end =
                                            SourcePos
                                              {line = 1, column = 2, name = ""}
                                        }
                                  , name = "x"
                                  , typ = Nothing
                                  })
                         , right =
                             VariableExpression
                               (Variable
                                  { location =
                                      SourceLocation
                                        { start =
                                            SourcePos
                                              {line = 1, column = 3, name = ""}
                                        , end =
                                            SourcePos
                                              {line = 1, column = 4, name = ""}
                                        }
                                  , name = "y"
                                  , typ = Nothing
                                  })
                         , typ = Nothing
                         })
                , right =
                    InfixExpression
                      (Infix
                         { location =
                             SourceLocation
                               { start =
                                   SourcePos {line = 1, column = 5, name = ""}
                               , end =
                                   SourcePos {line = 1, column = 10, name = ""}
                               }
                         , global =
                             Global
                               { location =
                                   SourceLocation
                                     { start =
                                         SourcePos
                                           {line = 1, column = 5, name = ""}
                                     , end =
                                         SourcePos
                                           {line = 1, column = 10, name = ""}
                                     }
                               , name = ParsedTextName "*"
                               , scheme = ParsedScheme
                               }
                         , left =
                             VariableExpression
                               (Variable
                                  { location =
                                      SourceLocation
                                        { start =
                                            SourcePos
                                              {line = 1, column = 5, name = ""}
                                        , end =
                                            SourcePos
                                              {line = 1, column = 6, name = ""}
                                        }
                                  , name = "z"
                                  , typ = Nothing
                                  })
                         , right =
                             InfixExpression
                               (Infix
                                  { location =
                                      SourceLocation
                                        { start =
                                            SourcePos
                                              {line = 1, column = 7, name = ""}
                                        , end =
                                            SourcePos
                                              {line = 1, column = 10, name = ""}
                                        }
                                  , global =
                                      Global
                                        { location =
                                            SourceLocation
                                              { start =
                                                  SourcePos
                                                    { line = 1
                                                    , column = 7
                                                    , name = ""
                                                    }
                                              , end =
                                                  SourcePos
                                                    { line = 1
                                                    , column = 10
                                                    , name = ""
                                                    }
                                              }
                                        , name = ParsedTextName "/"
                                        , scheme = ParsedScheme
                                        }
                                  , left =
                                      VariableExpression
                                        (Variable
                                           { location =
                                               SourceLocation
                                                 { start =
                                                     SourcePos
                                                       { line = 1
                                                       , column = 7
                                                       , name = ""
                                                       }
                                                 , end =
                                                     SourcePos
                                                       { line = 1
                                                       , column = 8
                                                       , name = ""
                                                       }
                                                 }
                                           , name = "y"
                                           , typ = Nothing
                                           })
                                  , right =
                                      LiteralExpression
                                        (NumberLiteral
                                           (Number
                                              { location =
                                                  SourceLocation
                                                    { start =
                                                        SourcePos
                                                          { line = 1
                                                          , column = 9
                                                          , name = ""
                                                          }
                                                    , end =
                                                        SourcePos
                                                          { line = 1
                                                          , column = 10
                                                          , name = ""
                                                          }
                                                    }
                                              , number = IntegerNumber 2
                                              , typ = Nothing
                                              }))
                                  , typ = Nothing
                                  })
                         , typ = Nothing
                         })
                , typ = Nothing
                }))))
  it
    "x+y+z"
    (shouldBe
       (parseText "" "x+y+z")
       (Right
          (InfixExpression
             (Infix
                { location =
                    SourceLocation
                      { start = SourcePos {line = 1, column = 1, name = ""}
                      , end = SourcePos {line = 1, column = 6, name = ""}
                      }
                , global =
                    Global
                      { location =
                          SourceLocation
                            { start =
                                SourcePos {line = 1, column = 1, name = ""}
                            , end = SourcePos {line = 1, column = 6, name = ""}
                            }
                      , name = ParsedTextName "+"
                      , scheme = ParsedScheme
                      }
                , left =
                    InfixExpression
                      (Infix
                         { location =
                             SourceLocation
                               { start =
                                   SourcePos {line = 1, column = 1, name = ""}
                               , end =
                                   SourcePos {line = 1, column = 4, name = ""}
                               }
                         , global =
                             Global
                               { location =
                                   SourceLocation
                                     { start =
                                         SourcePos
                                           {line = 1, column = 1, name = ""}
                                     , end =
                                         SourcePos
                                           {line = 1, column = 4, name = ""}
                                     }
                               , name = ParsedTextName "+"
                               , scheme = ParsedScheme
                               }
                         , left =
                             VariableExpression
                               (Variable
                                  { location =
                                      SourceLocation
                                        { start =
                                            SourcePos
                                              {line = 1, column = 1, name = ""}
                                        , end =
                                            SourcePos
                                              {line = 1, column = 2, name = ""}
                                        }
                                  , name = "x"
                                  , typ = Nothing
                                  })
                         , right =
                             VariableExpression
                               (Variable
                                  { location =
                                      SourceLocation
                                        { start =
                                            SourcePos
                                              {line = 1, column = 3, name = ""}
                                        , end =
                                            SourcePos
                                              {line = 1, column = 4, name = ""}
                                        }
                                  , name = "y"
                                  , typ = Nothing
                                  })
                         , typ = Nothing
                         })
                , right =
                    VariableExpression
                      (Variable
                         { location =
                             SourceLocation
                               { start =
                                   SourcePos {line = 1, column = 5, name = ""}
                               , end =
                                   SourcePos {line = 1, column = 6, name = ""}
                               }
                         , name = "z"
                         , typ = Nothing
                         })
                , typ = Nothing
                }))))
  it
    "x+ [should error]"
    (shouldBe
       (first (const ()) (parseText "" "x+"))
       (Left ()))
  it
    "x + + y [should error]"
    (shouldBe
       (first (const ()) (parseText "" "x + + x"))
       (Left ()))

types :: Spec
types = describe
          "Type"
          (do it
                "Integer"
                (shouldBe
                   (parseType "" "Integer")
                   (Right
                      (ConstantType
                         (TypeConstant
                            { location =
                                SourceLocation
                                  { start =
                                      SourcePos {line = 1, column = 1, name = ""}
                                  , end = SourcePos {line = 1, column = 8, name = ""}
                                  }
                            , name = IntegerTypeName
                            }))))
              it
                "Decimal 3"
                (shouldBe
                   (parseType "" "Decimal 3")
                   (Right
                      (ApplyType
                         (TypeApplication
                            { function =
                                ConstantType
                                  (TypeConstant
                                     { location =
                                         SourceLocation
                                           { start =
                                               SourcePos
                                                 {line = 1, column = 1, name = ""}
                                           , end =
                                               SourcePos
                                                 {line = 1, column = 8, name = ""}
                                           }
                                     , name = DecimalTypeName
                                     })
                            , argument =
                                ConstantType
                                  (TypeConstant
                                     { location =
                                         SourceLocation
                                           { start =
                                               SourcePos
                                                 {line = 1, column = 9, name = ""}
                                           , end =
                                               SourcePos
                                                 {line = 1, column = 10, name = ""}
                                           }
                                     , name = NatTypeName 3
                                     })
                            , location =
                                SourceLocation
                                  { start =
                                      SourcePos {line = 1, column = 1, name = ""}
                                  , end = SourcePos {line = 1, column = 10, name = ""}
                                  }
                            , kind = TypeKind
                            }))))
              it
                "Integer -> Decimal 3"
                (shouldBe
                   (parseType "" "Integer->Decimal 3")
                   (Right
                      (ApplyType
                         (TypeApplication
                            { function =
                                ApplyType
                                  (TypeApplication
                                     { function =
                                         ConstantType
                                           (TypeConstant
                                              { location =
                                                  SourceLocation
                                                    { start =
                                                        SourcePos
                                                          { line = 1
                                                          , column = 8
                                                          , name = ""
                                                          }
                                                    , end =
                                                        SourcePos
                                                          { line = 1
                                                          , column = 10
                                                          , name = ""
                                                          }
                                                    }
                                              , name = FunctionTypeName
                                              })
                                     , argument =
                                         ConstantType
                                           (TypeConstant
                                              { location =
                                                  SourceLocation
                                                    { start =
                                                        SourcePos
                                                          { line = 1
                                                          , column = 1
                                                          , name = ""
                                                          }
                                                    , end =
                                                        SourcePos
                                                          { line = 1
                                                          , column = 8
                                                          , name = ""
                                                          }
                                                    }
                                              , name = IntegerTypeName
                                              })
                                     , location =
                                         SourceLocation
                                           { start =
                                               SourcePos
                                                 {line = 1, column = 8, name = ""}
                                           , end =
                                               SourcePos
                                                 {line = 1, column = 10, name = ""}
                                           }
                                     , kind = FunKind TypeKind TypeKind
                                     })
                            , argument =
                                ApplyType
                                  (TypeApplication
                                     { function =
                                         ConstantType
                                           (TypeConstant
                                              { location =
                                                  SourceLocation
                                                    { start =
                                                        SourcePos
                                                          { line = 1
                                                          , column = 10
                                                          , name = ""
                                                          }
                                                    , end =
                                                        SourcePos
                                                          { line = 1
                                                          , column = 17
                                                          , name = ""
                                                          }
                                                    }
                                              , name = DecimalTypeName
                                              })
                                     , argument =
                                         ConstantType
                                           (TypeConstant
                                              { location =
                                                  SourceLocation
                                                    { start =
                                                        SourcePos
                                                          { line = 1
                                                          , column = 18
                                                          , name = ""
                                                          }
                                                    , end =
                                                        SourcePos
                                                          { line = 1
                                                          , column = 19
                                                          , name = ""
                                                          }
                                                    }
                                              , name = NatTypeName 3
                                              })
                                     , location =
                                         SourceLocation
                                           { start =
                                               SourcePos
                                                 {line = 1, column = 10, name = ""}
                                           , end =
                                               SourcePos
                                                 {line = 1, column = 19, name = ""}
                                           }
                                     , kind = TypeKind
                                     })
                            , location =
                                SourceLocation
                                  { start =
                                      SourcePos {line = 1, column = 8, name = ""}
                                  , end = SourcePos {line = 1, column = 10, name = ""}
                                  }
                            , kind = TypeKind
                            })))))

literals :: Spec
literals =
  it
    "Literal"
    (do shouldBe
          (parseText "" "[]")
          (Right
             (ArrayExpression
                (Array
                   { form = ()
                   , expressions = V.fromList []
                   , typ = Nothing
                   , location =
                       SourceLocation
                         { start = SourcePos {line = 1, column = 1, name = ""}
                         , end = SourcePos {line = 1, column = 3, name = ""}
                         }
                   })))
        shouldBe
          (parseText "" "[123,123]")
          (Right
             (ArrayExpression
                (Array
                   { form = ()
                   , expressions =
                       V.fromList
                         [ LiteralExpression
                             (NumberLiteral
                                (Number
                                   { location =
                                       SourceLocation
                                         { start =
                                             SourcePos
                                               {line = 1, column = 2, name = ""}
                                         , end =
                                             SourcePos
                                               {line = 1, column = 5, name = ""}
                                         }
                                   , number = IntegerNumber 123
                                   , typ = Nothing
                                   }))
                         , LiteralExpression
                             (NumberLiteral
                                (Number
                                   { location =
                                       SourceLocation
                                         { start =
                                             SourcePos
                                               {line = 1, column = 6, name = ""}
                                         , end =
                                             SourcePos
                                               {line = 1, column = 9, name = ""}
                                         }
                                   , number = IntegerNumber 123
                                   , typ = Nothing
                                   }))
                         ]
                   , typ = Nothing
                   , location =
                       SourceLocation
                         { start = SourcePos {line = 1, column = 1, name = ""}
                         , end = SourcePos {line = 1, column = 10, name = ""}
                         }
                   })))
        shouldBe
          (parseText "" "-123")
          (Right
             (LiteralExpression
                (NumberLiteral
                   (Number
                      { location =
                          SourceLocation
                            { start =
                                SourcePos {line = 1, column = 2, name = ""}
                            , end = SourcePos {line = 1, column = 5, name = ""}
                            }
                      , number = IntegerNumber (-123)
                      , typ = Nothing
                      }))))
        shouldBe
          (parseText "" "123")
          (Right
             (LiteralExpression
                (NumberLiteral
                   Number
                     { location =
                         SourceLocation
                           { start = SourcePos {name = "", line = 1, column = 1}
                           , end = SourcePos {name = "", line = 1, column = 4}
                           }
                     , number = IntegerNumber 123
                     , typ = Nothing
                     })))
        shouldBe
          (parseText "" "-123.0")
          (Right
             (LiteralExpression
                (NumberLiteral
                   (Number
                      { location =
                          SourceLocation
                            { start =
                                SourcePos {line = 1, column = 2, name = ""}
                            , end = SourcePos {line = 1, column = 7, name = ""}
                            }
                      , number =
                          DecimalNumber (Decimal {places = 1, integer = -1230})
                      , typ = Nothing
                      }))))
        shouldBe
          (parseText "" "123.0")
          (Right
             (LiteralExpression
                (NumberLiteral
                   (Number
                      { location =
                          SourceLocation
                            { start =
                                SourcePos {line = 1, column = 1, name = ""}
                            , end = SourcePos {line = 1, column = 6, name = ""}
                            }
                      , number =
                          DecimalNumber (Decimal {places = 1, integer = 1230})
                      , typ = Nothing
                      }))))
        shouldBe
          (parseText "" "123.123")
          (Right
             (LiteralExpression
                (NumberLiteral
                   (Number
                      { location =
                          SourceLocation
                            { start =
                                SourcePos {line = 1, column = 1, name = ""}
                            , end = SourcePos {line = 1, column = 8, name = ""}
                            }
                      , number =
                          DecimalNumber (Decimal {places = 3, integer = 123123})
                      , typ = Nothing
                      }))))
        shouldBe
          (parseText "" "0.000")
          (Right
             (LiteralExpression
                (NumberLiteral
                   (Number
                      { location =
                          SourceLocation
                            { start =
                                SourcePos {line = 1, column = 1, name = ""}
                            , end = SourcePos {line = 1, column = 6, name = ""}
                            }
                      , number =
                          DecimalNumber (Decimal {places = 3, integer = 0})
                      , typ = Nothing
                      })))))

globals :: Spec
globals =
  it
    "Globals"
    (do shouldBe
          (parseText
             ""
             "[@uuid:1ea653f3-67f7-4fad-9892-85ce6cbf10a7,@sha512:3ba402f10ef7807ab8767a44d57ed1b6dcfc84d629219a0603535993c93b6279ecb4aab48763b5b84b8c45d9ea2b90bf7356e06b063cc4478f2b817d66f449ad]")
          (Right
             (ArrayExpression
                (Array
                   { form = ()
                   , expressions =
                       V.fromList
                         [ GlobalExpression
                             (Global
                                { location =
                                    SourceLocation
                                      { start =
                                          SourcePos
                                            {line = 1, column = 2, name = ""}
                                      , end =
                                          SourcePos
                                            {line = 1, column = 44, name = ""}
                                      }
                                , name =
                                    ParsedUuid
                                      (Uuid
                                         "1ea653f3-67f7-4fad-9892-85ce6cbf10a7")
                                , scheme = ParsedScheme
                                })
                         , GlobalExpression
                             (Global
                                { location =
                                    SourceLocation
                                      { start =
                                          SourcePos
                                            {line = 1, column = 45, name = ""}
                                      , end =
                                          SourcePos
                                            {line = 1, column = 181, name = ""}
                                      }
                                , name =
                                   ParsedHash
                                      (Hash
                                         ($$("3ba402f10ef7807ab8767a44d57ed1b6dcfc84d629219a0603535993c93b6279ecb4aab48763b5b84b8c45d9ea2b90bf7356e06b063cc4478f2b817d66f449ad")))
                                , scheme = ParsedScheme
                                })
                         ]
                   , typ = Nothing
                   , location =
                       SourceLocation
                         { start = SourcePos {line = 1, column = 1, name = ""}
                         , end = SourcePos {line = 1, column = 182, name = ""}
                         }
                   })))
        shouldBe
          (parseText "" "abc")
          (Right
             (VariableExpression
                (Variable
                   { location =
                       SourceLocation
                         { start = SourcePos {line = 1, column = 1, name = ""}
                         , end = SourcePos {line = 1, column = 4, name = ""}
                         }
                   , name = "abc"
                   , typ = Nothing
                   })))
        shouldBe
          (parseText "" "x:y")
          (Right
             (LambdaExpression
                (Lambda
                   { location =
                       SourceLocation
                         { start = SourcePos {line = 1, column = 1, name = ""}
                         , end = SourcePos {line = 1, column = 4, name = ""}
                         }
                   , param =
                       Param
                         { location =
                             SourceLocation
                               { start =
                                   SourcePos {line = 1, column = 1, name = ""}
                               , end =
                                   SourcePos {line = 1, column = 2, name = ""}
                               }
                         , name = "x"
                         , typ = Nothing
                         }
                   , body =
                       VariableExpression
                         (Variable
                            { location =
                                SourceLocation
                                  { start =
                                      SourcePos
                                        {line = 1, column = 3, name = ""}
                                  , end =
                                      SourcePos
                                        {line = 1, column = 4, name = ""}
                                  }
                            , name = "y"
                            , typ = Nothing
                            })
                   , typ = Nothing
                   })))
        shouldSatisfy
          (parseText "" "x:x(y)")
          $(match [|Right
                      (LambdaExpression
                         (Lambda
                            { location =
                                SourceLocation
                                  { start = SourcePos {line = 1, column = 1, name = ""}
                                  , end = SourcePos {line = 1, column = 6, name = ""}
                                  }
                            , param =
                                Param
                                  { location =
                                      SourceLocation
                                        { start =
                                            SourcePos {line = 1, column = 1, name = ""}
                                        , end =
                                            SourcePos {line = 1, column = 2, name = ""}
                                        }
                                  , name = "x"
                                  , typ = Nothing
                                  }
                            , body =
                                ApplyExpression
                                  (Apply
                                     { location =
                                         SourceLocation
                                           { start =
                                               SourcePos
                                                 {line = 1, column = 5, name = ""}
                                           , end =
                                               SourcePos
                                                 {line = 1, column = 6, name = ""}
                                           }
                                     , function =
                                         VariableExpression
                                           (Variable
                                              { location =
                                                  SourceLocation
                                                    { start =
                                                        SourcePos
                                                          { line = 1
                                                          , column = 3
                                                          , name = ""
                                                          }
                                                    , end =
                                                        SourcePos
                                                          { line = 1
                                                          , column = 4
                                                          , name = ""
                                                          }
                                                    }
                                              , name = "x"
                                              , typ = Nothing
                                              })
                                     , argument =
                                         VariableExpression
                                           (Variable
                                              { location =
                                                  SourceLocation
                                                    { start =
                                                        SourcePos
                                                          { line = 1
                                                          , column = 5
                                                          , name = ""
                                                          }
                                                    , end =
                                                        SourcePos
                                                          { line = 1
                                                          , column = 6
                                                          , name = ""
                                                          }
                                                    }
                                              , name = "y"
                                              , typ = Nothing
                                              })
                                     , typ = Nothing
                                     })
                            , typ = Nothing
                            }))|]))

lambda :: Spec
lambda = it
           "Lambda"
           (shouldBe
              (parseText "" "x:123")
              (Right (LambdaExpression (Lambda {location = SourceLocation {start = SourcePos {line = 1, column = 1, name = ""}, end = SourcePos {line = 1, column = 6, name = ""}}, param = Param {location = SourceLocation {start = SourcePos {line = 1, column = 1, name = ""}, end = SourcePos {line = 1, column = 2, name = ""}}, name = "x", typ = Nothing}, body = LiteralExpression (NumberLiteral (Number {location = SourceLocation {start = SourcePos {line = 1, column = 3, name = ""}, end = SourcePos {line = 1, column = 6, name = ""}}, number = IntegerNumber 123, typ = Nothing})), typ = Nothing}))))

apply :: SpecWith ()
apply = it
          "Apply"
          (do shouldSatisfy
                (parseText "" "(x:x)(1)")
                $(match [|Right (ApplyExpression (Apply {location = SourceLocation {start = SourcePos {line = 1, column = 7, name = ""}, end = SourcePos {line = 1, column = 8, name = ""}}, function = LambdaExpression (Lambda {location = SourceLocation {start = SourcePos {line = 1, column = 2, name = ""}, end = SourcePos {line = 1, column = 5, name = ""}}, param = Param {location = SourceLocation {start = SourcePos {line = 1, column = 2, name = ""}, end = SourcePos {line = 1, column = 3, name = ""}}, name = "x", typ = Nothing}, body = VariableExpression (Variable {location = SourceLocation {start = SourcePos {line = 1, column = 4, name = ""}, end = SourcePos {line = 1, column = 5, name = ""}}, name = "x", typ = Nothing}), typ = Nothing}), argument = LiteralExpression (NumberLiteral (Number {location = SourceLocation {start = SourcePos {line = 1, column = 7, name = ""}, end = SourcePos {line = 1, column = 8, name = ""}}, number = IntegerNumber 1, typ = Nothing})), typ = Nothing}))|])
              shouldSatisfy
                (parseText "" "(x:y:1)(1,2)")
                $(match [|Right (ApplyExpression (Apply {location = SourceLocation {start = SourcePos {line = 1, column = 11, name = ""}, end = SourcePos {line = 1, column = 12, name = ""}}, function = ApplyExpression (Apply {location = SourceLocation {start = SourcePos {line = 1, column = 9, name = ""}, end = SourcePos {line = 1, column = 10, name = ""}}, function = LambdaExpression (Lambda {location = SourceLocation {start = SourcePos {line = 1, column = 2, name = ""}, end = SourcePos {line = 1, column = 7, name = ""}}, param = Param {location = SourceLocation {start = SourcePos {line = 1, column = 2, name = ""}, end = SourcePos {line = 1, column = 3, name = ""}}, name = "x", typ = Nothing}, body = LambdaExpression (Lambda {location = SourceLocation {start = SourcePos {line = 1, column = 4, name = ""}, end = SourcePos {line = 1, column = 7, name = ""}}, param = Param {location = SourceLocation {start = SourcePos {line = 1, column = 4, name = ""}, end = SourcePos {line = 1, column = 5, name = ""}}, name = "y", typ = Nothing}, body = LiteralExpression (NumberLiteral (Number {location = SourceLocation {start = SourcePos {line = 1, column = 6, name = ""}, end = SourcePos {line = 1, column = 7, name = ""}}, number = IntegerNumber 1, typ = Nothing})), typ = Nothing}), typ = Nothing}), argument = LiteralExpression (NumberLiteral (Number {location = SourceLocation {start = SourcePos {line = 1, column = 9, name = ""}, end = SourcePos {line = 1, column = 10, name = ""}}, number = IntegerNumber 1, typ = Nothing})), typ = Nothing}), argument = LiteralExpression (NumberLiteral (Number {location = SourceLocation {start = SourcePos {line = 1, column = 11, name = ""}, end = SourcePos {line = 1, column = 12, name = ""}}, number = IntegerNumber 2, typ = Nothing})), typ = Nothing}))|]))

sigs :: SpecWith ()
sigs =
  it
    "Signatures"
    (do shouldBe
          (parseText "" "123 :: Integer")
          (Right
             (LiteralExpression
                (NumberLiteral
                   (Number
                      { location =
                          SourceLocation
                            { start =
                                SourcePos {line = 1, column = 1, name = ""}
                            , end = SourcePos {line = 1, column = 4, name = ""}
                            }
                      , number = IntegerNumber 123
                      , typ =
                          Just
                            (ConstantType
                               (TypeConstant
                                  { location =
                                      SourceLocation
                                        { start =
                                            SourcePos
                                              {line = 1, column = 8, name = ""}
                                        , end =
                                            SourcePos
                                              {line = 1, column = 15, name = ""}
                                        }
                                  , name = IntegerTypeName
                                  }))
                      }))))
        shouldBe
          (parseText "" "123 :: Decimal 1")
          (Right
             (LiteralExpression
                (NumberLiteral
                   (Number
                      { location =
                          SourceLocation
                            { start =
                                SourcePos {line = 1, column = 1, name = ""}
                            , end = SourcePos {line = 1, column = 4, name = ""}
                            }
                      , number = IntegerNumber 123
                      , typ =
                          Just
                            (ApplyType
                               (TypeApplication
                                  { function =
                                      ConstantType
                                        (TypeConstant
                                           { location =
                                               SourceLocation
                                                 { start =
                                                     SourcePos
                                                       { line = 1
                                                       , column = 8
                                                       , name = ""
                                                       }
                                                 , end =
                                                     SourcePos
                                                       { line = 1
                                                       , column = 15
                                                       , name = ""
                                                       }
                                                 }
                                           , name = DecimalTypeName
                                           })
                                  , argument =
                                      ConstantType
                                        (TypeConstant
                                           { location =
                                               SourceLocation
                                                 { start =
                                                     SourcePos
                                                       { line = 1
                                                       , column = 16
                                                       , name = ""
                                                       }
                                                 , end =
                                                     SourcePos
                                                       { line = 1
                                                       , column = 17
                                                       , name = ""
                                                       }
                                                 }
                                           , name = NatTypeName 1
                                           })
                                  , location =
                                      SourceLocation
                                        { start =
                                            SourcePos
                                              {line = 1, column = 8, name = ""}
                                        , end =
                                            SourcePos
                                              {line = 1, column = 17, name = ""}
                                        }
                                  , kind = TypeKind
                                  }))
                      })))))

records :: SpecWith ()
records =
  it
    "Record"
    (shouldBe
       (parseText "" "{a: 123+3/k, b: 452.2}")
       (Right
          (RecordExpression
             (Record
                { fields =
                    [ FieldE
                        { name = FieldName {unFieldName = "a"}
                        , expression =
                            InfixExpression
                              (Infix
                                 { location =
                                     SourceLocation
                                       { start =
                                           SourcePos
                                             {line = 1, column = 5, name = ""}
                                       , end =
                                           SourcePos
                                             {line = 1, column = 12, name = ""}
                                       }
                                 , global =
                                     Global
                                       { location =
                                           SourceLocation
                                             { start =
                                                 SourcePos
                                                   { line = 1
                                                   , column = 5
                                                   , name = ""
                                                   }
                                             , end =
                                                 SourcePos
                                                   { line = 1
                                                   , column = 12
                                                   , name = ""
                                                   }
                                             }
                                       , name = ParsedTextName "+"
                                       , scheme = ParsedScheme
                                       }
                                 , left =
                                     LiteralExpression
                                       (NumberLiteral
                                          (Number
                                             { location =
                                                 SourceLocation
                                                   { start =
                                                       SourcePos
                                                         { line = 1
                                                         , column = 5
                                                         , name = ""
                                                         }
                                                   , end =
                                                       SourcePos
                                                         { line = 1
                                                         , column = 8
                                                         , name = ""
                                                         }
                                                   }
                                             , number = IntegerNumber 123
                                             , typ = Nothing
                                             }))
                                 , right =
                                     InfixExpression
                                       (Infix
                                          { location =
                                              SourceLocation
                                                { start =
                                                    SourcePos
                                                      { line = 1
                                                      , column = 9
                                                      , name = ""
                                                      }
                                                , end =
                                                    SourcePos
                                                      { line = 1
                                                      , column = 12
                                                      , name = ""
                                                      }
                                                }
                                          , global =
                                              Global
                                                { location =
                                                    SourceLocation
                                                      { start =
                                                          SourcePos
                                                            { line = 1
                                                            , column = 9
                                                            , name = ""
                                                            }
                                                      , end =
                                                          SourcePos
                                                            { line = 1
                                                            , column = 12
                                                            , name = ""
                                                            }
                                                      }
                                                , name = ParsedTextName "/"
                                                , scheme = ParsedScheme
                                                }
                                          , left =
                                              LiteralExpression
                                                (NumberLiteral
                                                   (Number
                                                      { location =
                                                          SourceLocation
                                                            { start =
                                                                SourcePos
                                                                  { line = 1
                                                                  , column = 9
                                                                  , name = ""
                                                                  }
                                                            , end =
                                                                SourcePos
                                                                  { line = 1
                                                                  , column = 10
                                                                  , name = ""
                                                                  }
                                                            }
                                                      , number = IntegerNumber 3
                                                      , typ = Nothing
                                                      }))
                                          , right =
                                              VariableExpression
                                                (Variable
                                                   { location =
                                                       SourceLocation
                                                         { start =
                                                             SourcePos
                                                               { line = 1
                                                               , column = 11
                                                               , name = ""
                                                               }
                                                         , end =
                                                             SourcePos
                                                               { line = 1
                                                               , column = 12
                                                               , name = ""
                                                               }
                                                         }
                                                   , name = "k"
                                                   , typ = Nothing
                                                   })
                                          , typ = Nothing
                                          })
                                 , typ = Nothing
                                 })
                        , location =
                            SourceLocation
                              { start =
                                  SourcePos {line = 1, column = 3, name = ""}
                              , end =
                                  SourcePos {line = 1, column = 4, name = ""}
                              }
                        }
                    , FieldE
                        { name = FieldName {unFieldName = "b"}
                        , expression =
                            LiteralExpression
                              (NumberLiteral
                                 (Number
                                    { location =
                                        SourceLocation
                                          { start =
                                              SourcePos
                                                { line = 1
                                                , column = 17
                                                , name = ""
                                                }
                                          , end =
                                              SourcePos
                                                { line = 1
                                                , column = 22
                                                , name = ""
                                                }
                                          }
                                    , number =
                                        DecimalNumber
                                          (Decimal {places = 1, integer = 4522})
                                    , typ = Nothing
                                    }))
                        , location =
                            SourceLocation
                              { start =
                                  SourcePos {line = 1, column = 15, name = ""}
                              , end =
                                  SourcePos {line = 1, column = 16, name = ""}
                              }
                        }
                    ]
                , location =
                    SourceLocation
                      { start = SourcePos {line = 1, column = 1, name = ""}
                      , end = SourcePos {line = 1, column = 23, name = ""}
                      }
                , typ = Nothing
                }))))

strings :: SpecWith ()
strings =
  describe
    "Strings"
    (do it
          "\"a\""
          (shouldBe
             (parseText "" "\"a\"")
             (Right
                (LiteralExpression
                   (TextLiteral
                      (LiteralText
                         { location =
                             SourceLocation
                               { start =
                                   SourcePos {line = 1, column = 1, name = ""}
                               , end =
                                   SourcePos {line = 1, column = 4, name = ""}
                               }
                         , text = "a"
                         , typ = Nothing
                         })))))
        it
          "\"speech \"\" \\\\ here\""
          (shouldBe
             (parseText "" "\"speech \"\" \\\\ here\"")
             (Right
                (LiteralExpression
                   (TextLiteral
                      (LiteralText
                         { location =
                             SourceLocation
                               { start =
                                   SourcePos {line = 1, column = 1, name = ""}
                               , end =
                                   SourcePos {line = 1, column = 20, name = ""}
                               }
                         , text = "speech \" \\\\ here"
                         , typ = Nothing
                         }))))))

variants :: SpecWith ()
variants =
  describe
    "Variants"
    (do it
          "#true"
          (shouldBe
             (parseText "" "#true")
             (Right
                (VariantExpression
                   (Variant
                      { location =
                          SourceLocation
                            { start =
                                SourcePos {line = 1, column = 2, name = ""}
                            , end = SourcePos {line = 1, column = 6, name = ""}
                            }
                      , typ = Nothing
                      , tag = TagName {unTagName = "true"}
                      , argument = Nothing
                      }))))
        it
          "#ok(1)"
          (shouldBe
             (parseText "" "#ok(1)")
             (Right
                (VariantExpression
                   (Variant
                      { location =
                          SourceLocation
                            { start =
                                SourcePos {line = 1, column = 2, name = ""}
                            , end = SourcePos {line = 1, column = 4, name = ""}
                            }
                      , typ = Nothing
                      , tag = TagName {unTagName = "ok"}
                      , argument =
                          Just
                            (LiteralExpression
                               (NumberLiteral
                                  (Number
                                     { location =
                                         SourceLocation
                                           { start =
                                               SourcePos
                                                 { line = 1
                                                 , column = 5
                                                 , name = ""
                                                 }
                                           , end =
                                               SourcePos
                                                 { line = 1
                                                 , column = 6
                                                 , name = ""
                                                 }
                                           }
                                     , number = IntegerNumber 1
                                     , typ = Nothing
                                     })))
                      })))))

_implicitcalls :: Spec
_implicitcalls =
  describe
    "Implicit calls"
    (do it
          "foo{x: 1}"
          (shouldSatisfy
             (parseText "" "foo{x:1}")
             $(match [|Right
                         (ApplyExpression
                            (Apply
                               { location =
                                   SourceLocation
                                     { start =
                                         SourcePos {line = 1, column = 4, name = ""}
                                     , end = SourcePos {line = 1, column = 9, name = ""}
                                     }
                               , function =
                                   VariableExpression
                                     (Variable
                                        { location =
                                            SourceLocation
                                              { start =
                                                  SourcePos
                                                    {line = 1, column = 1, name = ""}
                                              , end =
                                                  SourcePos
                                                    {line = 1, column = 4, name = ""}
                                              }
                                        , name = "foo"
                                        , typ = Nothing
                                        })
                               , argument =
                                   RecordExpression
                                     (Record
                                        { fields =
                                            [ FieldE
                                                { name = FieldName {unFieldName = "x"}
                                                , expression =
                                                    LiteralExpression
                                                      (NumberLiteral
                                                         (Number
                                                            { location =
                                                                SourceLocation
                                                                  { start =
                                                                      SourcePos
                                                                        { line = 1
                                                                        , column = 7
                                                                        , name = ""
                                                                        }
                                                                  , end =
                                                                      SourcePos
                                                                        { line = 1
                                                                        , column = 8
                                                                        , name = ""
                                                                        }
                                                                  }
                                                            , number = IntegerNumber 1
                                                            , typ = Nothing
                                                            }))
                                                , location =
                                                    SourceLocation
                                                      { start =
                                                          SourcePos
                                                            { line = 1
                                                            , column = 6
                                                            , name = ""
                                                            }
                                                      , end =
                                                          SourcePos
                                                            { line = 1
                                                            , column = 7
                                                            , name = ""
                                                            }
                                                      }
                                                }
                                            ]
                                        , location =
                                            SourceLocation
                                              { start =
                                                  SourcePos
                                                    {line = 1, column = 4, name = ""}
                                              , end =
                                                  SourcePos
                                                    {line = 1, column = 9, name = ""}
                                              }
                                        , typ = Nothing
                                        })
                               , typ = Nothing
                               }))|]))
        it
          "foo[1,2,3]"
          (shouldSatisfy
             (parseText "" "foo[1,2,3]")
             $(match [|Right
                         (ApplyExpression
                            (Apply
                               { location =
                                   SourceLocation
                                     { start =
                                         SourcePos {line = 1, column = 4, name = ""}
                                     , end = SourcePos {line = 1, column = 11, name = ""}
                                     }
                               , function =
                                   VariableExpression
                                     (Variable
                                        { location =
                                            SourceLocation
                                              { start =
                                                  SourcePos
                                                    {line = 1, column = 1, name = ""}
                                              , end =
                                                  SourcePos
                                                    {line = 1, column = 4, name = ""}
                                              }
                                        , name = "foo"
                                        , typ = Nothing
                                        })
                               , argument =
                                   ArrayExpression
                                     (Array
                                        { form = ()
                                        , expressions =
                                            V.fromList
                                              [ LiteralExpression
                                                  (NumberLiteral
                                                     (Number
                                                        { location =
                                                            SourceLocation
                                                              { start =
                                                                  SourcePos
                                                                    { line = 1
                                                                    , column = 5
                                                                    , name = ""
                                                                    }
                                                              , end =
                                                                  SourcePos
                                                                    { line = 1
                                                                    , column = 6
                                                                    , name = ""
                                                                    }
                                                              }
                                                        , number = IntegerNumber 1
                                                        , typ = Nothing
                                                        }))
                                              , LiteralExpression
                                                  (NumberLiteral
                                                     (Number
                                                        { location =
                                                            SourceLocation
                                                              { start =
                                                                  SourcePos
                                                                    { line = 1
                                                                    , column = 7
                                                                    , name = ""
                                                                    }
                                                              , end =
                                                                  SourcePos
                                                                    { line = 1
                                                                    , column = 8
                                                                    , name = ""
                                                                    }
                                                              }
                                                        , number = IntegerNumber 2
                                                        , typ = Nothing
                                                        }))
                                              , LiteralExpression
                                                  (NumberLiteral
                                                     (Number
                                                        { location =
                                                            SourceLocation
                                                              { start =
                                                                  SourcePos
                                                                    { line = 1
                                                                    , column = 9
                                                                    , name = ""
                                                                    }
                                                              , end =
                                                                  SourcePos
                                                                    { line = 1
                                                                    , column = 10
                                                                    , name = ""
                                                                    }
                                                              }
                                                        , number = IntegerNumber 3
                                                        , typ = Nothing
                                                        }))
                                              ]
                                        , typ = Nothing
                                        , location =
                                            SourceLocation
                                              { start =
                                                  SourcePos
                                                    {line = 1, column = 4, name = ""}
                                              , end =
                                                  SourcePos
                                                    {line = 1, column = 11, name = ""}
                                              }
                                        })
                               , typ = Nothing
                               }))|])))

parser2 :: Spec
parser2 =
  describe
    "Parser2"
    (do itParsersMatch "_"
        itParsersMatch "\"some string with quote \"\" inside \""
        itParsersMatch "\"foo\""
        itParsersMatch "#ok(123)"
        itParsersMatch "[1,_]"
        itParsersMatch "#none"
        itParsersMatch "[#none,#ok(123)]"
        itParsersMatch "{\"foo\":123,\"bar\":45}"
        itParsersMatch "{a:1}"
        itParsersMatch "{foo:123,bar:45}"
        itParsersMatch "[{foo:123.123,bar:45.0},{foo:123.123,bar:45.0}]"
        sequence_
          [ itParsersMatch string
          | string <- ["[1,23,456]", "123", "[[1,2],[3,4]]"]
          ]
        sequence_
          [ itParsersMatch string
          | string <- ["[-1,-23,-456]", "-123", "[[-1,-2],[-3,-4]]"]
          ])
  where
    _itParsersMatchPending text' =
      it
        (T.unpack text')
        (do pending
            shouldBe
              (first (const ()) (Parser2.parseText "" text'))
              (first (const ()) (parseText "" text')))
    itParsersMatch text' =
      it
        (T.unpack text')
        (shouldBe
           (first (const ()) (Parser2.parseText "" text'))
           (first (const ()) (parseText "" text')))

dotcalls :: Spec
dotcalls = do
  it
    "[1,2,3].@prim:array_map(f)"
    (shouldSatisfy
       (parseText "" "[1,2,3].@prim:array_map(f)")
       $(match
           [|Right
               (ApplyExpression
                  (Apply
                     { function =
                         ApplyExpression
                           (Apply
                              { function =
                                  GlobalExpression
                                    (Global {name = ParsedPrim MapFunction})
                              , argument =
                                  VariableExpression (Variable {name = "f"})
                              , style = PrefixApply
                              })
                     , argument = ArrayExpression _
                     , typ = Nothing
                     , style = DotApply
                     }))|]))
  it
    "[1,2,3].@prim:array_length()"
    (shouldSatisfy
       (parseText "" "[1,2,3].@prim:array_length()")
       $(match
           [|Right
               (ApplyExpression
                  (Apply
                     { function =
                         GlobalExpression
                           (Global {name = ParsedPrim LengthFunction})
                     , argument = ArrayExpression _
                     , typ = Nothing
                     , style = DotApply
                     }))|]))
  it
    "[1,2,3].@prim:array_map(f).@prim:array_length()"
    (shouldSatisfy
       (parseText "" "[1,2,3].@prim:array_map(f).@prim:array_length()")
       $(match
           [|Right
               (ApplyExpression
                  (Apply
                     { function =
                         GlobalExpression
                           (Global {name = ParsedPrim LengthFunction})
                     , argument =
                         ApplyExpression
                           (Apply
                              { function =
                                  ApplyExpression
                                    (Apply
                                       { function =
                                           GlobalExpression
                                             (Global
                                                {name = ParsedPrim MapFunction})
                                       , argument =
                                           VariableExpression
                                             (Variable {name = "f"})
                                       , style = PrefixApply
                                       })
                              , argument = ArrayExpression _
                              , typ = Nothing
                              , style = DotApply
                              })
                     , typ = Nothing
                     , style = DotApply
                     }))|]))
  it
    "{students:[1,2,3]}.students.@prim:array_length()"
    (shouldSatisfy
       (parseText "" "{students:[1,2,3]}.students.@prim:array_length()")
       $(match
           [|Right
               (ApplyExpression
                  (Apply
                     { function =
                         GlobalExpression
                           (Global
                              { name = ParsedPrim LengthFunction
                              , scheme = ParsedScheme
                              })
                     , argument =
                         PropExpression
                           (Prop
                              { expression = RecordExpression _
                              , name = FieldName {unFieldName = "students"}
                              , typ = Nothing
                              })
                     , typ = Nothing
                     , style = DotApply
                     }))|]))

rich :: Spec
rich = do
  it
    "Cell ref example"
    (shouldSatisfy
       (parseText "" "@cell:uuid:1ea653f3-67f7-4fad-9892-85ce6cbf10a7")
       $(match
           [|Right
               (CellRefExpression
                  (CellRef
                     { address =
                         RefUuid (Uuid "1ea653f3-67f7-4fad-9892-85ce6cbf10a7")
                     }))|]))
  it
    "Rich text example"
    (shouldSatisfy
       (parseText
          ""
          "@prim:rich_doc([@prim:rich_paragraph([@prim:rich_text(\"Hello!\")])])")
       $(match
           [|Right
               (ApplyExpression
                  (Apply
                     { function =
                         GlobalExpression (Global {name = ParsedPrim RichDoc})
                     , argument =
                         ArrayExpression
                           (Array
                              { expressions =
                                  [ ApplyExpression
                                      (Apply
                                         { function =
                                             GlobalExpression
                                               (Global
                                                  { name =
                                                      ParsedPrim RichParagraph
                                                  })
                                         , argument =
                                             ArrayExpression
                                               (Array
                                                  { expressions =
                                                      [ ApplyExpression
                                                          (Apply
                                                             { function =
                                                                 GlobalExpression
                                                                   (Global
                                                                      { name =
                                                                          ParsedPrim
                                                                            RichText
                                                                      })
                                                             , argument =
                                                                 LiteralExpression
                                                                   (TextLiteral
                                                                      (LiteralText
                                                                         { text =
                                                                             "Hello!"
                                                                         }))
                                                             , style =
                                                                 PrefixApply
                                                             })
                                                      ]
                                                  })
                                         })
                                  ]
                              })
                     }))|]))
