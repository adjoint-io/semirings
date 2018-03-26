{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE DeriveFoldable #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}

{-# OPTIONS_GHC -Wall #-}

module Data.Semiring.Poly
  ( Poly(..)
  , polyBind 
  , polyJoin
  , collapse
  , composePoly
  , horner
  ) where

import           Data.Foldable (Foldable)
import qualified Data.Foldable as Foldable
import           Data.Ord (Ordering(..), compare)
import           Data.Vector (Vector)
import qualified Data.Vector as Vector
import           GHC.Generics (Generic, Generic1)
import qualified Prelude as P
import           Prelude (($), (.), otherwise)

--import Data.Ring (Ring(..), (-), minus)

import Data.Semiring (Semiring(zero,one,plus,times), (+), (*))

polyJoin :: Semiring a => Poly (Poly a) -> Poly a
polyJoin (Poly x) = collapse x

collapse :: Semiring a => Vector (Poly a) -> Poly a
collapse = Foldable.foldr composePoly zero

-- | The type of polynomials in one variable
newtype Poly  a   = Poly { unPoly :: Vector a }
  deriving (P.Eq, P.Ord, P.Read, P.Show, Generic, Generic1,
            P.Functor, P.Foldable)

empty :: Poly a
empty = Poly $ Vector.empty

singleton :: a -> Poly a
singleton = Poly . Vector.singleton

composePoly :: Semiring a => Poly a -> Poly a -> Poly a
composePoly (Poly x) y = horner y (P.fmap (Poly . Vector.singleton) x)

infixl 1 `polyBind`

polyBind :: forall a b. Semiring b => Poly a -> (a -> Poly b) -> Poly b
p `polyBind` f = polyJoin (P.fmap f p)

-- | Horner's scheme for evaluating a polynomial in a semiring
horner :: (Semiring a, Foldable t) => a -> t a -> a
horner x = Foldable.foldr (\c val -> c + x * val) zero

polyPlus, polyTimes :: Semiring a => Vector a -> Vector a -> Vector a
polyPlus xs ys =
  case compare (Vector.length xs) (Vector.length ys) of
    EQ -> Vector.zipWith (+) xs ys
    LT -> Vector.unsafeAccumulate (+) ys (Vector.indexed xs)
    GT -> Vector.unsafeAccumulate (+) xs (Vector.indexed ys)
polyTimes signal kernel
  | Vector.null signal = Vector.empty
  | Vector.null kernel = Vector.empty
  | otherwise = Vector.generate (slen P.+ klen P.- 1) f
  where
    f n = Foldable.foldl'
      (\a k ->
        a +
        Vector.unsafeIndex signal k *
        Vector.unsafeIndex kernel (n P.- k)) zero [kmin .. kmax]
      where
        !kmin = P.max 0 (n P.- (klen P.- 1))
        !kmax = P.min n (slen P.- 1)
    !slen = Vector.length signal
    !klen = Vector.length kernel

instance Semiring a => Semiring (Poly a) where
  zero = empty
  one  = singleton one

  plus x y  = Poly $ polyPlus  (unPoly x) (unPoly y)
  times x y = Poly $ polyTimes (unPoly x) (unPoly y)