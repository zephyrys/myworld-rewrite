{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE MultiParamTypeClasses #-}

------------------------------------------------------
-- |
-- Module : Engine
-- Maintainer : Milo Cress
-- Stability : Lol
-- Portability : who even knows
--
-- It's like a professional raytracer except really slow /and/ low quality!
------------------------------------------------------
module Engine ( Object (..)
              , NormalObject (..)
              , Map2
              , GradMap2
              , GradMapInfo (..)
              , Camera (..)
              , renderScene
              , PointLight
              , Sphere (..)
              , Plane (..)
              , EngineConfig (..)
              ) where

import Engine.Class
import Engine.Config
import Engine.Trace
import Engine.Light

import Map
import Map.Dimension

import Linear.V2
import Linear.V3
import Linear.V
import Linear.Metric (normalize)
import Linear.Epsilon (Epsilon)

import Data.Maybe (fromMaybe)
import Control.Monad.Trans.Maybe (runMaybeT)

import Map.PixelMap (black, writePixelMap)

-- | This probably belongs somewhere else. TODO: implement quaternions for objects, make "Camera" an object
data Camera a = Camera { camFov    :: a            -- ^ angle, in degrees
                       , camPos    :: V3 a
                       , camFacing :: V3 a         -- ^ Normal vector of the camera's face (the direction the camera is facing)
                       , camUp     :: V3 a         -- ^ Must be perpendicular to camFacing
                       , camScale  :: a            -- ^ scale
                       , camRes    :: Resolution 2 -- ^ resolution
                       }

-- | Renders a scene to the disk.
renderScene :: (_)
            => EngineConfig a b -> Camera a -> p -> [V3 a] -> FilePath -> IO ()
renderScene conf cam@Camera{..} objects lights path = writePixelMap path camRes m where
  m = do
    p <- uvToWorld cam <$> fromV <$> getPoint
    return . fromMaybe black
           . runEngine (runMaybeT . traceColor p . normalize $ p - camPos) conf
           $ (EngineState objects lights)

ratio :: ( Fractional a) => Resolution 2 -> a
ratio res = let
  (V2 x y) = fromV $ fromIntegral <$> res
  in y / x

uvToWorld :: (Floating a, Epsilon a)
          => Camera a -> V2 a -> V3 a
uvToWorld Camera{..} (V2 u v) = camPos
                              + (camFacing * pure camScale)
                              + (pure lenX * dir)
                              + (pure lenY * camUp) where
  dir = normalize $ cross camUp camFacing
  (V2 resX resY) = fromV $ fromIntegral <$> camRes
  -- I have no idea why these work, but don't touch it!
  lenY = -((u / resX) - 0.5) * scale
  lenX = ((v / resY) - 0.5) * scale * ratio camRes

  scale = (sin . toRadians $ (camFov / 2)) * camScale

toRadians :: ( Fractional a , Floating a )
          => a -> a
toRadians theta = pi * theta / 180
