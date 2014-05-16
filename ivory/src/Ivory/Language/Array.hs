{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleInstances #-}

module Ivory.Language.Array where

import Ivory.Language.IBool
import Ivory.Language.Area
import Ivory.Language.Proxy
import Ivory.Language.Ref
import Ivory.Language.Sint
import Ivory.Language.Type
import Ivory.Language.SizeOf
import qualified Ivory.Language.Syntax as I

import GHC.TypeLits (Nat)

-- Arrays ----------------------------------------------------------------------

-- Note: it is assumed in ivory-opts and the ivory-backend that the associated
-- type is an Sint32, so this should not be changed in the front-end without
-- modifying the other packages.
type IxRep = Sint32

-- | Values in the range @0 .. n-1@.
newtype Ix (n :: Nat) = Ix { getIx :: I.Expr }

instance (ANat n) => IvoryType (Ix n) where
     ivoryType _ = ivoryType (Proxy :: Proxy IxRep)

instance (ANat n) => IvoryVar (Ix n) where
  wrapVar    = wrapVarExpr
  unwrapExpr = getIx

instance (ANat n) => IvoryExpr (Ix n) where
  wrapExpr = Ix

instance (ANat n) => IvoryStore (Ix n)

instance (ANat n) => Num (Ix n) where
  (*)           = ixBinop (*)
  (-)           = ixBinop (-)
  (+)           = ixBinop (+)
  abs           = ixUnary abs
  signum        = ixUnary signum
  fromInteger   = mkIx . fromInteger

instance (ANat n) => IvoryEq  (Ix n)
instance (ANat n) => IvoryOrd (Ix n)

instance (ANat n) => IvorySizeOf (Stored (Ix n)) where
  sizeOfBytes _ = sizeOfBytes (Proxy :: Proxy (Stored IxRep))

fromIx :: ANat n => Ix n -> IxRep
fromIx = wrapExpr . unwrapExpr

-- | Casting from a bounded Ivory expression to an index.  This is safe,
-- although the value may be truncated.  Furthermore, indexes are always
-- positive.
toIx :: (IvoryExpr a, Bounded a, ANat n) => a -> Ix n
toIx = mkIx . unwrapExpr

-- | The number of elements that an index covers.
ixSize :: forall n. (ANat n) => Ix n -> Integer
ixSize _ = fromTypeNat (aNat :: NatType n)

arrayLen :: forall s len area n ref.
            (Num n, ANat len, IvoryArea area, IvoryRef ref)
         => ref s (Array len area) -> n
arrayLen _ = fromInteger (fromTypeNat (aNat :: NatType len))

-- | Array indexing.
(!) :: forall s len area ref.
       ( ANat len, IvoryArea area, IvoryRef ref
       , IvoryExpr (ref s (Array len area)), IvoryExpr (ref s area))
    => ref s (Array len area) -> Ix len -> ref s area
arr ! ix = wrapExpr (I.ExpIndex ty (unwrapExpr arr) ixRep (getIx ix))
  where
  ty    = ivoryArea (Proxy :: Proxy (Array len area))
  ixRep = ivoryType (Proxy :: Proxy IxRep)

-- XXX don't export
mkIx :: forall n. (ANat n) => I.Expr -> Ix n
mkIx e = wrapExpr (I.ExpToIx e base)
  where
  base = ixSize (undefined :: Ix n)

-- XXX don't export
ixBinop :: (ANat n)
        => (I.Expr -> I.Expr -> I.Expr)
        -> (Ix n -> Ix n -> Ix n)
ixBinop f x y = mkIx $ f (rawIxVal x) (rawIxVal y)

-- XXX don't export
ixUnary :: (ANat n) => (I.Expr -> I.Expr) -> (Ix n -> Ix n)
ixUnary f = mkIx . f . rawIxVal

-- XXX don't export
rawIxVal :: ANat n => Ix n -> I.Expr
rawIxVal n = case unwrapExpr n of
               I.ExpToIx e _  -> e
               e@(I.ExpVar _) -> e
               e             -> error $ "Front-end: can't unwrap ixVal: "
                             ++ show e
