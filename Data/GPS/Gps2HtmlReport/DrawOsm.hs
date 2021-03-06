
module Data.GPS.Gps2HtmlReport.DrawOsm (
  generateOsmMap -- :: String -> [WptType] -> IO ()
  ) where

import Prelude
import Data.GPS
import Network.HTTP.Enumerator
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as L
import Control.Monad
import Data.Bits
import Graphics.GD
import Data.Maybe

import Data.GPS.Gps2HtmlReport.JourneyStats

baseurl = "http://tile.openstreetmap.org"

data TileCoords = TileCoords { minX :: Int
                     , maxX :: Int  
                     , minY :: Int  
                     , maxY :: Int 
                     } 

tileNumbers :: Double -> Double -> Int -> [(Int,Int)]
tileNumbers latitude longitude zoom = 
             let xtile = ((longitude+180) / 360) * fromInteger (shift (1::Integer) zoom)
                 tmp = log (tan (latitude*pi / 180) + secant (latitude * pi / 180))
                 ytile = ((1-tmp / pi) / 2.0) * fromInteger (shift (1::Integer) zoom)
                 bounds x = [ceiling x, floor x]
             in [(xt,yt) | xt <- bounds xtile, yt <- bounds ytile]

maxTile :: [(Int,Int)] -> (Int,Int)
maxTile [] = error "There is no max tile of an empty list"
maxTile (x:xs) = go x xs
  where
    go a [] = a
    go a (y:ys) = if fst y >= fst a && snd y >= snd a then go y ys else go a ys

secant :: Floating a => a -> a
secant a = 1 / cos a

initCoords :: TileCoords
initCoords = TileCoords {minX = 1000000, maxX = -1000, minY = 1000000, maxY = -1000}

-- | Determines the minimum and maximum of the X and Y tiles
-- to be downloaded from OSM
determineTiles :: [WptType] -> TileCoords -> Int -> TileCoords
determineTiles [] _ _ = initCoords
determineTiles [wpt] tCoords zoom =
       let curMinX = minX tCoords
           curMaxX = maxX tCoords
           curMinY = minY tCoords
           curMaxY = maxY tCoords
           tiles = tileNumbers (value (lat wpt)) (value (lon wpt)) zoom
           newMaxX = maximum $ curMaxX : map fst tiles
           newMinX = minimum $ curMinX : map fst tiles
           newMaxY = maximum $ curMaxY : map snd tiles
           newMinY = minimum $ curMinY : map snd tiles 
       in tCoords {minX = newMinX, maxX = newMaxX, minY = newMinY, maxY = newMaxY}

determineTiles (wpt:wpts) tCoords zoom = 
       let tileScope = determineTiles [wpt] tCoords zoom
       in determineTiles wpts tileScope zoom

maxNumAutoTiles = 32

zoomCalc :: TileCoords -> Int
zoomCalc tCoords = 
   let numxtiles = maxX tCoords - minX tCoords + 1
       numytiles = maxY tCoords - minY tCoords + 1
       div = getZoomDiv numxtiles numytiles 0
   in 16 - div

getZoomDiv x y i
   | (x+1)*(y+1) > maxNumAutoTiles = getZoomDiv (shiftR x 1) (shiftR y 1) (i+1)
   | otherwise = i

-- | Takes the boundaries of the OSM tiles, and generates
-- [(Int,Int)] containing a list of all OSM tiles that
-- need downloading
selectedTiles :: TileCoords -> [(Int,Int)]
selectedTiles tCoords = 
         let minx = minX tCoords
             maxx = maxX tCoords
             miny = minY tCoords
             maxy = maxY tCoords
         in [(i,j) | i <- [minx..maxx], j <- [miny..maxy]]
       

-- | Formats the URL string
urlStr xTile yTile zoom = baseurl ++"/"++show zoom++"/"++show xTile++"/"++show yTile++".png"


-- | Takes the URL of a given OSM tile and uses curl to download it
downloadFile :: String -> IO Image
downloadFile url = do
  response <- liftM (B.concat . L.toChunks) (simpleHttp url)
  loadPngByteString response

-- | Takes the boundaries of the OSM tiles covering the
-- the 'Trail', uses 'placeTile' to download the tile
-- and to place each tile on the background layer
makeOSMLayer :: TileCoords -> Int -> IO Image
makeOSMLayer tCoords zoom = do
        backgroundImg <- newImage (((maxX tCoords - minX tCoords)+1)*256,((maxY tCoords - minY tCoords)+1)*256)
        mapM_ (\(a,b) -> placeTile a b backgroundImg tCoords zoom) (selectedTiles tCoords)
        return backgroundImg

-- | Used to create a mosaic of all downloaded OSM tiles to generate
-- the background layer for plotting the 'Trail' onto the 'Image'
placeTile :: Int -> Int -> Graphics.GD.Image -> TileCoords -> Int -> IO ()
placeTile x y backgroundImg tCoords zoom = do
          img <- downloadFile $ urlStr x y zoom
          copyRegion (0,0) (256,256) img (256*(x-minX tCoords),256*(y-minY tCoords)) backgroundImg

projectMercToLat :: Floating a => a -> a
projectMercToLat rely = (180 / pi) * atan (sinh rely)

-- | Used by @pixelPosForCoord@ for N,S,E,W coordinates for (x,y) values
project :: Int -> Int -> Int -> (Double,Double,Double,Double)
project x y zoom = 
  let unit = 1.0 / (2.0 ** fromIntegral zoom)
      rely1 = fromIntegral y * unit
      rely2 = rely1 + unit
      limity = pi
      rangey = 2.0 * limity
      rely1' = limity - rangey * rely1
      rely2' = limity - rangey * rely2
      lat1 = projectMercToLat rely1'
      lat2 = projectMercToLat rely2'
      unit' = 360.0 / (2.0 ** fromIntegral zoom)
      long1 = (-180.0) + fromIntegral x * unit'
  in (lat2,long1,lat1,long1+unit') -- S,W,N,E
  
-- | Takes a WptType, and the OSM tile boundaries
-- and generates (x,y) points to be placed on the 'Image'
pixelPosForCoord :: (Lon a, Lat a, Integral t, Integral t1) => [a] -> TileCoords -> Int -> (t, t1)
pixelPosForCoord [] _ _ = (0,0)
pixelPosForCoord [wpt] tCoord zoom =
             let lat' = value $ lat wpt
                 lon' = value $ lon wpt
                 tile = maxTile $ tileNumbers lat' lon' zoom
                 xoffset = (fst tile - minX tCoord) * 256
                 yoffset = (snd tile - minY tCoord) * 256
                 (south,west,north,east) = (uncurry project tile zoom)
                 x = round $ (lon' - west) * 256.0 / (east - west) + fromIntegral xoffset
                 y = round $ (lat' - north) * 256.0 / (south - north) + fromIntegral yoffset
             in (x,y)


-- | Takes the 'WptType' and draws lines between every
-- point to point connection in the 'Trail'
drawLines :: [WptType] -> TileCoords -> Image -> Image -> Int -> IO ()
drawLines [] _ _ _ _ = return ()
drawLines [_] _ _ _ _ = return ()
drawLines (wpt:wpts) tCoord img lineImg zoom = do
       let start = pixelPosForCoord [wpt] tCoord zoom
           end = pixelPosForCoord [head wpts] tCoord zoom
           minEle = fromMaybe 0 $ fmap snd $ findPoint wpts wpt ele (<)
           maxEle = fromMaybe 0 $ fmap snd $ findPoint wpts wpt ele (>)
       drawLine' start end img lineImg (minEle,fromMaybe 0 $ ele wpt,maxEle)
       drawLines wpts tCoord img lineImg zoom

-- | Sets the colour for a single line segment in the track,
--   and 
drawLine' :: Point -> Point -> Image -> Image -> (Double,Double,Double) -> IO ()
drawLine' start end img lineImg (minEle,ele',maxEle) = do
   fillImage color lineImg
   setBrush img lineImg
   drawLine (fst start,snd start) (fst end,snd end) (unPCREOption brushed) img
   where range = maxEle - minEle
         x' = ele' - minEle
         x'' = x' / range
         color = lineColor $ round $ 255.0*x''

-- | Uses a sliding scale for the red value in the RGB Color
-- to show a sliding color from green to yellow in accordance
-- with the relative elevation of a given WptType in the Trail
lineColor :: Int -> Graphics.GD.Color
lineColor redVal = rgb redVal 255 0

-- | Adds the copyright text in accordance with
-- http://wiki.openstreetmap.org/wiki/Legal_FAQ
addCopyright :: Graphics.GD.Image -> IO (Graphics.GD.Point, Graphics.GD.Point, Graphics.GD.Point, Graphics.GD.Point)
addCopyright img = do
         size <- imageSize img
         let copyrightS = "Tile images © OpenStreetMap (and) contributors, CC-BY-SA"
             pos = (10,snd size-10)
             black = rgb 0 0 0
         useFontConfig True
         drawString "monospace" 6.0 0.0 pos copyrightS black img

-- | If the generated OSM image has a greater width than 800 pixels, it is scaled to have a width of 800 pixels.
fitToWidth :: Image -> IO Image
fitToWidth img = do
   dimensions <- imageSize img
   let width = fst dimensions
   if width > 800 then resizeImg img dimensions else return img

-- | Uses the GraphicsMagick bindings the resize the image
resizeImg :: Image -> (Int,Int) -> IO Image  
resizeImg img dimensions = do
   let resizeRatio = fromIntegral (fst dimensions) / 800.0
       height = round (fromIntegral (snd dimensions) / resizeRatio)
   resizeImage 800 height img

-- | Takes the destination directory for the web content,
-- the (Trail WptType), and uses the DrawOsm functions
-- to generate an `osm.png' file showing the trail.
generateOsmMap :: String -> [WptType] -> IO ()
generateOsmMap webDir points = do
  let tiles = determineTiles points initCoords 16
      zoom = zoomCalc tiles
      tiles' = determineTiles points initCoords zoom
  img <- makeOSMLayer tiles' zoom
  lineImg  <- newImage (5,5)
  drawLines points tiles' img lineImg zoom
  savePngFile (webDir++"/osm_fullsize.png") img
  img' <- fitToWidth img
  addCopyright img'
  savePngFile (webDir++"/osm.png") img'
