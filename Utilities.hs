-- Utility functions that don't fit in a particular library.

module Utilities where

-- System Libraries
import System.Directory (getCurrentDirectory, setCurrentDirectory)
import Distribution.Simple.Utils (withTempDirectory)
import Control.Concurrent (threadDelay)
import System.FilePath (dropExtensions)
import Distribution.Verbosity (silent)
import System.IO (stdout, hFlush)
import Data.List (dropWhileEnd)
import Text.Regex.Posix ((=~))
import Text.Printf (printf)

-- Custom Libraries
import Shell

type Pattern = (String,String)

type Regex = String

----------------
-- CUSTOM OUTPUT
----------------
putStrLnA :: Colouror -> String -> IO ()
putStrLnA colour s = putStrA colour $ s ++ "\n"

putStrA :: Colouror -> String -> IO ()
putStrA colour s = putStr $ "aura >>= " ++ colour s

printListWithTitle :: Colouror -> Colouror -> String -> [String] -> IO ()
printListWithTitle _ _ _ [] = return ()
printListWithTitle titleColour itemColour msg items = do
  putStrLnA titleColour msg
  mapM_ (putStrLn . itemColour) items
  putStrLn ""

-- Like break, but kills the element that triggered the break.
hardBreak :: (a -> Bool) -> [a] -> ([a],[a])
hardBreak _ [] = ([],[])
hardBreak p xs = (firstHalf, secondHalf')
    where firstHalf   = takeWhile (not . p) xs
          secondHalf  = dropWhile (not . p) xs
          secondHalf' = if null secondHalf then [] else tail secondHalf

lStrip :: String -> String
lStrip xs = dropWhile (== ' ') xs

rStrip :: String -> String
rStrip xs = dropWhileEnd (== ' ') xs

tripleFst :: (a,b,c) -> a
tripleFst (a,_,_) = a

tripleSnd :: (a,b,c) -> b
tripleSnd (_,b,_) = b

tripleThrd :: (a,b,c) -> c
tripleThrd (_,_,c) = c

-- Replaces a (p)attern with a (t)arget in a line if possible.
replaceByPatt :: [Pattern] -> String -> String
replaceByPatt [] line = line
replaceByPatt ((p,t):ps) line | p == m    = replaceByPatt ps (b ++ t ++ a)
                              | otherwise = replaceByPatt ps line
                         where (b,m,a) = line =~ p :: (String,String,String)

withTempDir :: FilePath -> IO a -> IO a
withTempDir name action = do
  originalDirectory <- getCurrentDirectory
  withTempDirectory silent originalDirectory name (\dir -> do     
     setCurrentDirectory dir
     result <- action
     setCurrentDirectory originalDirectory
     return result)

-- Given a number of selections, allows the user to choose one.
getSelection :: [String] -> IO String
getSelection [] = return ""
getSelection choiceLabels = do
  let quantity = length choiceLabels
      valids   = map show [1..quantity]
      padding  = show . length . show $ quantity
      choices  = zip valids choiceLabels
  mapM_ (\(n,c)-> printf ("%" ++ padding ++ "s. %s\n") n c) choices
  putStr ">> "
  hFlush stdout
  userChoice <- getLine
  case userChoice `lookup` choices of
    Just valid -> return valid
    Nothing    -> getSelection choiceLabels  -- Ask again.

timedMessage :: Int -> [String] -> IO ()
timedMessage delay msgs = mapM_ printMessage msgs
    where printMessage msg = putStr msg >> hFlush stdout >> threadDelay delay

-- Takes a prompt message and a regex of valid answer patterns.
yesNoPrompt :: String -> Regex -> IO Bool
yesNoPrompt msg regex = do
  putStrA yellow $ msg ++ " [y/n] "
  hFlush stdout
  response <- getLine
  return (response =~ regex :: Bool)

optionalPrompt :: Bool -> String -> IO Bool
optionalPrompt True msg = yesNoPrompt msg "^(y|Y|\\B)"
optionalPrompt False _  = return True

searchLines :: Regex -> [String] -> [String]
searchLines pat allLines = filter (\line -> line =~ pat) allLines

wordsLines :: String -> [String]
wordsLines ls = lines ls >>= words

notNull :: [a] -> Bool
notNull = not . null

-- Opens the editor of the user's choice.
openEditor :: String -> String -> IO ()
openEditor editor file = shellCmd editor [file] >> return ()

-- Is there a more built-in replacement for `tar` that wouldn't be
-- required as a listed dependency in the PKGBUILD?
uncompress :: FilePath -> IO FilePath
uncompress file = do
  _ <- quietShellCmd' "bsdtar" ["-zxvf",file]
  return $ dropExtensions file

fromRight :: Either a b -> b
fromRight (Right x) = x
fromRight (Left _)  = error "Value given was a Left."

-- The Int argument is the final length of the padded String,
-- not the length of the pad.
postPad :: [a] -> a -> Int -> [a]
postPad xs x len = take len $ xs ++ repeat x

prePad :: [a] -> a -> Int -> [a]
prePad xs x len = take (len - length xs) (repeat x) ++ xs

inDir :: FilePath -> IO a -> IO a
inDir dir action = do
  curr <- getCurrentDirectory
  setCurrentDirectory dir
  result <- action
  setCurrentDirectory curr
  return result
