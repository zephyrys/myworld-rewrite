{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE FlexibleContexts #-}
------------------------------------------------------
-- |
-- Module : Engine.Trace
-- Maintainer : Milo Cress
-- Stability : Lol
-- Portability : who even knows
--
-- Internal raytracing engine
------------------------------------------------------
module Engine.Trace (traceColor) where

import Engine.Class
import Engine.Light
import Engine.Config

import Map.PixelMap (white)

import Linear.V3 (V3(..))
-- import Linear.Epsilon (Epsilon)
import Linear.Metric (normalize, dot, distance)

import Control.Monad (guard)

import Data.Maybe (fromMaybe)

import Control.Monad.Trans.Maybe (MaybeT, runMaybeT)
import Control.Monad.Reader (lift)

-- import Control.Monad.Trans.List (runListT)

import Data.List (genericLength)

traceDist :: (_) => V3 a -> V3 a -> MaybeT (Engine a b s) a
traceDist point ray = go 0 0 where
  go d n = do
    EngineConfig{..} <- lift getConfig
    scene <- lift getScene
    -- lights <- lift getLights
    let dist = sdf (point + pure d * ray) scene
    guard $ n < maxSteps
    guard $ dist < maxDist
    if dist < minDist
      then return d
      else go (dist + d) (succ n)
{-# INLINE traceDist #-}

traceRay :: (_) => V3 a -> V3 a -> MaybeT (Engine a b s) (V3 a)
traceRay point ray = do
  d <- traceDist point ray
  return $ point + ray * pure d
{-# INLINE traceRay #-}

-- | Traces a ray from a given point in a direction of a given ray
-- to return a color.
traceColor :: (_)
           => V3 a -> V3 a -> MaybeT (Engine a b s) (V3 c)
traceColor point ray = do
  scene <- lift getScene
  p <- traceRay point ray
  let n = normal p scene
      ambient = 0.1
      c = fromIntegral <$> white
  diffuse <- shadows p n
  return $ floor <$> clamp 0 255 <$> c * pure (ambient + diffuse)
{-# INLINE traceColor #-}

average :: (Fractional a) => [a] -> a
average xs = sum xs / genericLength xs
{-# INLINE average #-}

clamp :: (Ord a) => a -> a -> a -> a
clamp mn mx = max mn . min mx
{-# INLINE clamp #-}

shadows :: (_) => V3 a -> V3 a -> MaybeT (Engine a b s) a
shadows p n = do
  ls <- lift getLights
  conf@EngineConfig{..} <- lift getConfig
  state <- lift getState
  return $ average $ do
    l <- ls
    let shade = if shadowsEnabled
          then runEngine (shadow p n l) conf state
          else 1.0
    return . (* shade)
           . clamp 0 1
           $ dot (normalize $ l - p) n
{-# INLINE shadows #-}

shadow :: (_)
       => V3 a -> V3 a -> PointLight a -> Engine a b s a
shadow point _ l = fmap (fromMaybe 0.0) $ runMaybeT $ do
  EngineConfig{..} <- lift getConfig
  let dir = normalize $ point - l
  p <- traceRay l dir
  lift (p `near` l) >>= guard
  return 1.0
{-# INLINE shadow #-}

near :: (Floating a, Ord a)
     => V3 a -> V3 a -> Engine a b s Bool
near v w = do
  EngineConfig{..} <- getConfig
  return $ distance v w <= 100
{-# INLINE near #-}
