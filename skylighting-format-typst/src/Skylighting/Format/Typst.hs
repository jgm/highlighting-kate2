{-# LANGUAGE CPP                 #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Skylighting.Format.Typst (
         formatTypstInline
       , formatTypstBlock
       , styleToTypst
       ) where

import Control.Monad (mplus)
import Data.Char (isSpace)
import Data.List (sort)
import qualified Data.Map as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Skylighting.Types
import Text.Printf
#if !MIN_VERSION_base(4,11,0)
import Data.Semigroup
#endif

formatTypst :: Bool -> [SourceLine] -> Text
formatTypst inline = Text.intercalate (Text.singleton '\n')
                       . map (sourceLineToTypst inline)

-- | Formats tokens as Typst using custom commands inside
-- @|@ characters. Assumes that @|@ is defined as a short verbatim
-- command by the macros produced by 'styleToTypst'.
-- A @KeywordTok@ is rendered using @\\KeywordTok{..}@, and so on.
formatTypstInline :: FormatOptions -> [SourceLine] -> Text
formatTypstInline _opts ls = "\\VERB|" <> formatTypst True ls <> "|"

sourceLineToTypst :: Bool -> SourceLine -> Text
sourceLineToTypst inline = mconcat . map (tokenToTypst inline)

tokenToTypst :: Bool -> Token -> Text
tokenToTypst inline (NormalTok, txt)
  | Text.all isSpace txt = escapeTypst inline txt
tokenToTypst inline (toktype, txt)   = Text.cons '\\'
  (Text.pack (show toktype) <> "{" <> escapeTypst inline txt <> "}")

escapeTypst :: Bool -> Text -> Text
escapeTypst inline = Text.concatMap escapeTypstChar
  where escapeTypstChar c =
         case c of
           '\\' -> "\\textbackslash{}"
           '{'  -> "\\{"
           '}'  -> "\\}"
           '|' | inline -> "\\VerbBar{}" -- used in inline verbatim
           '_'  -> "\\_"
           '&'  -> "\\&"
           '%'  -> "\\%"
           '#'  -> "\\#"
           '`'  -> "\\textasciigrave{}"
           '\'' -> "\\textquotesingle{}"
           '-'  -> "{-}" -- prevent ligatures
           '~'  -> "\\textasciitilde{}"
           '^'  -> "\\^{}"
           '>'  -> "\\textgreater{}"
           '<'  -> "\\textless{}"
           _    -> Text.singleton c

-- Typst

-- | Format tokens as a Typst @Highlighting@ environment inside a
-- @Shaded@ environment.  @Highlighting@ and @Shaded@ are
-- defined by the macros produced by 'styleToTypst'.  @Highlighting@
-- is a verbatim environment using @fancyvrb@; @\\@, @{@, and @}@
-- have their normal meanings inside this environment, so that
-- formatting commands work.  @Shaded@ is either nothing
-- (if the style's background color is default) or a @snugshade@
-- environment from @framed@, providing a background color
-- for the whole code block, even if it spans multiple pages.
formatTypstBlock :: FormatOptions -> [SourceLine] -> Text
formatTypstBlock opts ls = Text.unlines
  ["\\begin{Shaded}"
  ,"\\begin{Highlighting}[" <>
   (if numberLines opts
       then "numbers=left," <>
            (if startNumber opts == 1
                then ""
                else ",firstnumber=" <>
                     Text.pack (show (startNumber opts))) <> ","
       else Text.empty) <> "]"
  ,formatTypst False ls
  ,"\\end{Highlighting}"
  ,"\\end{Shaded}"]

-- | Converts a 'Style' to a set of Typst macro definitions,
-- which should be placed in the document's preamble.
-- Note: default Typst setup doesn't allow boldface typewriter font.
-- To make boldface work in styles, you need to use a different typewriter
-- font. This will work for computer modern:
--
-- > \DeclareFontShape{OT1}{cmtt}{bx}{n}{<5><6><7><8><9><10><10.95><12><14.4><17.28><20.74><24.88>cmttb10}{}
--
-- Or, with xelatex:
--
-- > \usepackage{fontspec}
-- > \setmainfont[SmallCapsFont={* Caps}]{Latin Modern Roman}
-- > \setsansfont{Latin Modern Sans}
-- > \setmonofont[SmallCapsFont={Latin Modern Mono Caps}]{Latin Modern Mono Light}
--
styleToTypst :: Style -> Text
styleToTypst f = Text.unlines $
  [ "\\usepackage{color}"
  , "\\usepackage{fancyvrb}"
  , "\\newcommand{\\VerbBar}{|}"
  , "\\newcommand{\\VERB}{\\Verb[commandchars=\\\\\\{\\}]}"
  , "\\DefineVerbatimEnvironment{Highlighting}{Verbatim}{commandchars=\\\\\\{\\}}"
  , "% Add ',fontsize=\\small' for more characters per line"
  ] ++
  (case backgroundColor f of
        Nothing          -> ["\\newenvironment{Shaded}{}{}"]
        Just (RGB r g b) -> ["\\usepackage{framed}"
                            ,Text.pack
                              (printf "\\definecolor{shadecolor}{RGB}{%d,%d,%d}" r g b)
                            ,"\\newenvironment{Shaded}{\\begin{snugshade}}{\\end{snugshade}}"])
  ++ sort (map (macrodef (defaultColor f) (Map.toList (tokenStyles f)))
            (enumFromTo KeywordTok NormalTok))

macrodef :: Maybe Color -> [(TokenType, TokenStyle)] -> TokenType -> Text
macrodef defaultcol tokstyles tokt = "\\newcommand{\\"
  <> Text.pack (show tokt)
  <> "}[1]{"
  <> Text.pack (co . ul . bf . it . bg $ "#1")
  <> "}"
  where tokf = case lookup tokt tokstyles of
                     Nothing -> defStyle
                     Just x  -> x
        ul x = if tokenUnderline tokf
                  then "\\underline{" <> x <> "}"
                  else x
        it x = if tokenItalic tokf
                  then "\\textit{" <> x <> "}"
                  else x
        bf x = if tokenBold tokf
                  then "\\textbf{" <> x <> "}"
                  else x
        bcol = fromColor `fmap` tokenBackground tokf
                  :: Maybe (Double, Double, Double)
        bg x = case bcol of
                    Nothing        -> x
                    Just (r, g, b) ->
                       printf "\\colorbox[rgb]{%0.2f,%0.2f,%0.2f}{%s}" r g b x
        col  = fromColor `fmap` (tokenColor tokf `mplus` defaultcol)
                  :: Maybe (Double, Double, Double)
        co x = case col of
                    Nothing        -> x
                    Just (r, g, b) ->
                        printf "\\textcolor[rgb]{%0.2f,%0.2f,%0.2f}{%s}" r g b x

