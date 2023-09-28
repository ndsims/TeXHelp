import Foundation

var contents: String = ""
contents = " ́\\mathop and \\underline"
var goodContents = " \\mathop and \\underline"
contents = " ́ \\mathop ́ "
contents = "§1196 TEX82 PART 48: BUILDING MATH LISTS 431\n1196. The unsave is done after everything else here; hence an appearance of ‘\\mathsurround’ inside of ‘$...$’ affects the spacing at these particular $’s. This is consistent with the conventions of ‘$$...$$’, since ‘\\abovedisplayskip’ inside a display affects the space above that display.\n⟨ Finish math in text 1196 ⟩ ≡\nbegin tail append (new math (math surround , before )); cur mlist ← p; cur style ← text style ; mlist penalties ← (mode > 0); mlist to hlist ; link (tail ) ← link (temp head );\nwhile link (tail ) ̸= null do tail ← link (tail );\ntail append (new math (math surround , after )); space factor ← 1000; unsave ;\nend\nThis code is used in section 1194.\n1197. TEX gets to the following part of the program when the first ‘$’ ending a display has been scanned.\n⟨ Check that another $ follows 1197 ⟩ ≡ begin get x token;\nif cur cmd ̸= math shift then\nbegin print err (\"Display␣math␣should␣end␣with␣$$\");\nhelp2 (\"The␣`$ ́␣that␣I␣just␣saw␣supposedly␣matches␣a␣previous␣`$$ ́.\") (\"So␣I␣shall␣assume␣that␣you␣typed␣`$$ ́␣both␣times.\"); back error; end;\nend\nThis code is used in sections 1194, 1194, and 1206.\n1198. We have saved the worst for last: The fussiest part of math mode processing occurs when a displayed\nformula is being centered and placed with an optional equation number. ⟨ Local variables for finishing a displayed formula 1198 ⟩ ≡\n{ box containing the equation } { width of the equation }\nb: pointer ;\nw: scaled ;\nz: scaled;\ne: scaled ;\nq: scaled;\nd: scaled ;\ns: scaled ;\ng1 , g2 : small number ; { glue parameter codes for before and after } r: pointer ; { kern node used to position the display }\nt: pointer ; { tail of adjustment list } This code is used in section 1194.\n{ width of the line }\n{ width of equation number }\n{ width of equation number plus space to separate from equation } { displacement of equation in the line }\n{ move the line right this much }\n"


contents = "74 Chapter 15. Changing Clefs, Keys and Meters\n\\zendeăxtr4a4ct“notes” region within which material is centered, you may use the\ncommand \\Changeclefs, as in the following:\nGS 11 J7R 12 H7 13\nwhich was coded as\n     \\generalmeter{\\meterC}\n     \\startextract%\n     \\NOTEs\\en  %\n     \\def\\atnextbar{\\znotes\\centerHpause{11}\\en}%\n     \\setclef1\\bass\\Changeclefs%\n     \\setleftrepeat%\n     \\generalmeter{\\allabreve}%\n     \\changecontext%\n     \\NOTEs\\en\n     \\def\\atnextbar{\\znotes\\centerHpause{12}\\en}%\n     \\setclef1\\treble\\Changeclefs%\n     \\setrightrepeat\\bar%\n     \\NOTEs\\en\n     \\def\\atnextbar{\\znotes\\centerHpause{13}\\en}%\n     \\endextract\nClef changes initiated with the \\setclef command\n                      "

//contents = "\\NOTEs\\en  %\n     \\def\\atnextbar{\\znotes\\centerHpause{11}\\en}%\n     "

contents = "\\commandWithUniCodeăx, \\commandWithSpace \\commandWithBrace{ \\command\\commandFollowing\\commandWithNumber1a \\commandWithAt@hi \\commandWithNewline\n \\begin{envSimple} \\begin{envNumber1} \\begin{} \\begin{envAt@} \\commandAtEnd "

contents = """
112 Chapter 23. Lyrics
        \\Notes\\hu{ih}\\en\\bar
        \\notes\\qu{gihh}\\en\\bar
        \\Notes\\wh g\\en
        \\endextract
        \\end{music}
5. Moving a word in any direction \\setlyrics{alto}{\\kernm3ex1.∼∼firstsyllable...}
\\setlyrics{alto}{...\\kern1exword...} \\setlyrics{alto}{...\\lower2pt\\hbox{word}...} \\setlyrics{alto}{...\\raise2pt\\hbox{word}...}
\\def\\strut{\\vbox to 2\\Interligne{}}\\setlyrics{alto}{\\lyrlayout{\\strut}...}
control distance between verses \\lyrlayout{\\vphantom{Mp(\\lowlyrlink} minimum distance between verses
\\setbox\\lyrstrutbox=\\hbox{\\vphantom{yM\\lyrlink}}
redefine default lyrstrut
6. Placing of accents can be made easier as shows this example: \\catcode‘\\ä\\active \\defä{\\"a} \\catcode‘\\ö\\active \\defö{\\"o}
\\setlyrics1{å ä ö} \\assignlyrics1{} Gˇˇˇ \\assignlyrics11
\\catcode‘\\å\\active \\letå\\aa
left-move verse number right-move a single word lower a single word
raise a single word
                                      \\startextract
                              \\NOtes\\qa{ggg}\\en
                              \\zendextract
7. Using an 8-bit encoded characterset. If you use default (Computer Modern) fonts, you will want to switch to the EC variants by putting \\input musixec af- ter \\input musixtex in your source file.
"""
    


NSString(string: contents).length //length is bigger
contents.count // length is smaller!


//https://regex101.com is helpful
var searchCount = 0

func searchContents(contents: String) -> [[String:NSRange]] {
    
    let regEx: String = ""
        + "\\\\begin" // search for \begin
        + "\\{" // search for left brace
        + "(" //  begin CAPTURE GROUP 1
        + "[a-zA-Z]+" // set with any chacter a-Z, repeated on or more times
        + ")" // end CAPTURE GROUP 1
        + "\\}" // closing brace;
        + "|" //append or operator
        + "\\\\" //search for \
        + "("  //begin CAPTURE GROUP 2
        + "[a-zA-Z]+" // basic letters, one or more times
        + ")" //end CAPTURE GROUP 2
        + "(?=[" // start look ahead assertion for a set
        + "\\s" // any white space
        + "\\{" // open brace
        + "%"   // comment start
        + "\\\\" // a single \
        + "," // comma
        + "." // full stop
        + "])" // end set of look ahead assertions
    
    var myRegEx: NSRegularExpression
    do {
        myRegEx = try NSRegularExpression(pattern: regEx, options: NSRegularExpression.Options.anchorsMatchLines)
    }
    catch {
        fatalError("invalid regex")
    }
    
    let myResults = myRegEx.matches(in: contents, options: NSRegularExpression.MatchingOptions.init(), range: NSRange(location: 0, length: NSString(string: contents).length))
    
    var returnValues: [[String: NSRange]] = []
    
    let skippedCommands: Set<String> = [
        "begin",
        "def",
        "let",
    ]
    
    for myResult in myResults{
        searchCount += 1
        var thisRange = myResult.range(at: 1) // range of 1st match
        if thisRange.location == NSNotFound {
            thisRange = myResult.range(at: 2) // range of 2nd match
        }
        let comstr = NSString(string: contents).substring(with:thisRange)
        if skippedCommands.contains(comstr) {continue}
        returnValues.append([comstr:thisRange])
    }
    return returnValues
}

print(searchContents(contents: contents))

