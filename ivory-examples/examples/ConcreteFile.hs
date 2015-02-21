{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE OverloadedStrings #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}

--
-- C-like syntax for Ivory, parsed from a file.
--
-- Copyright (C) 2014, Galois, Inc.
-- All rights reserved.
--

module ConcreteFile where

import Ivory.Language
import Ivory.Stdlib.String
import Ivory.Compile.C.CmdlineFrontend

e :: IBool
e = (4::Sint32) >? 3

type SomeInt = Uint32

macroStmts ::
     (Num a, IvoryStore a, IvoryInit a, GetAlloc eff ~ Scope s)
  => a -> a -> Ivory eff ()
macroStmts x y = do
  a <- local (ival 0)
  store a (x + y)

macroStmtsRet ::
     (Num a, IvoryStore a, IvoryInit a, GetAlloc eff ~ Scope s)
  => a -> a -> Ivory eff a
macroStmtsRet x y = do
  a <- local (ival 0)
  store a (x + y)
  return =<< deref a

macroExp :: IvoryOrd a => a -> a -> IBool
macroExp x y = do
  x <? y

printf :: Def ('[IString] :-> Sint32)
printf  = importProc "printf" "stdio.h"

printf2 :: Def ('[IString,Sint32] :-> Sint32)
printf2  = importProc "printf" "stdio.h"

toIx' :: ANat n => Uint32 -> Ix n
toIx' ix = toIx (twosComplementCast ix)

concreteIvory :: Module
concreteIvory = package "concreteIvory" $ do
  incl printf
  incl printf2
  inclHeader "stdio.h" -- so the header isn't just in the .c file

[ivoryFile|examples/file.ivory|]

main :: IO ()
main = runCompiler [concreteIvory, examplesfile, stdlibStringModule] stdlibStringArtifacts
  initialOpts {outDir = Just "concrete-ivory", constFold = True}
