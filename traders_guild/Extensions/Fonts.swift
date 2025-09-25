//
//  Fonts.swift
//  traders_guild
//
//  Created by Al Hennessey on 21/09/2025.
//

import SwiftUI


/*
 ------------------------
 HEADERS
 ------------------------
 - .largeTitle
    • Size: 34pt
    • Weight: Regular
    • Line Height: ~41pt
    • Usage: Very large titles (onboarding, landing screens)

 - .title
    • Size: 28pt
    • Weight: Regular
    • Line Height: ~34pt
    • Usage: Primary screen titles

 - .title2
    • Size: 22pt
    • Weight: Regular
    • Line Height: ~28pt
    • Usage: Secondary titles / section headers

 - .title3
    • Size: 20pt
    • Weight: Regular
    • Line Height: ~25pt
    • Usage: Smaller headers

 ------------------------
 BODY TEXT
 ------------------------
 - .headline
    • Size: 17pt
    • Weight: Semibold
    • Line Height: ~22pt
    • Usage: Emphasized body text

 - .subheadline
    • Size: 15pt
    • Weight: Regular
    • Line Height: ~20pt
    • Usage: Secondary body text, metadata

 - .body
    • Size: 17pt
    • Weight: Regular
    • Line Height: ~22pt
    • Usage: Default for paragraphs and most UI text

 - .callout
    • Size: 16pt
    • Weight: Regular
    • Line Height: ~21pt
    • Usage: Highlighted or emphasized callouts

 ------------------------
 CAPTIONS / FOOTNOTES
 ------------------------
 - .footnote
    • Size: 13pt
    • Weight: Regular
    • Line Height: ~18pt
    • Usage: Support text, legal, hints

 - .caption
    • Size: 12pt
    • Weight: Regular
    • Line Height: ~16pt
    • Usage: Labels, small text below items

 - .caption2
    • Size: 11pt
    • Weight: Regular
    • Line Height: ~13pt
    • Usage: The smallest caption style (rare, tiny annotations)
*/

enum AppFonts {
    static func title(size: CGFloat = 24) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }

    
    // Small notice is used for: welcomeScreen info
    static func smallNotice(size: CGFloat = 11) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    
    // Small notice is used for: welcomeScreen info
    static func buttonText(size: CGFloat = 17) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    
    
}
