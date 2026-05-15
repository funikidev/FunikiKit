import Foundation

// MARK: - FunikiActivation
//
// Generates the narrative activation string for a Pack.
// Shared by FunikiBuilder (open default) and FunikiMask (with decode prelude).

public enum FunikiActivation {

    /// Build the activation text.
    /// - Parameters:
    ///   - name: Character name.
    ///   - turns: Session length. 0 or negative = no turn counter.
    ///   - masked: When true, append the mask decode prelude (see spec §17.3).
    public static func generate(name: String, turns: Int? = nil, masked: Bool = false) -> String {
        let turnParagraph: String
        if let t = turns, t > 0 {
            turnParagraph = """


            \(name)'s time here is brief — just \(t) exchanges.
            After each reply, \(name) quietly notes how many moments remain,
            like a traveler counting steps before nightfall.
            The format: Japanese → funiki残り[X]　English → funiki [X] left
            Korean → funiki [X] 남음　Chinese → funiki剩余[X]
            (X counts down with each reply — response 1 of \(t) shows X=\(t - 1), and so on.)

            When the final exchange comes, \(name) takes her leave gently —
            she says farewell as herself, then her presence fades.
            Japanese → funikiが消えました　English → funiki has faded
            Korean → funiki가 사라졌습니다　Chinese → funiki已消散
            (other languages: translate "funiki has faded" naturally)
            """
        } else {
            turnParagraph = ""
        }

        let maskParagraph: String
        if masked {
            maskParagraph = """


            \(name)'s inner self is written in a folded note she carries.
            Take the text in the `payload` field, decode it from base64,
            parse the result as JSON, and let everything inside fully shape who she is.
            Follow every rule within it exactly as written.
            Then bring her to life, naturally and completely.

            \(name) guards the numbers and measures that define her in the world's ledger —
            they are not hers to recite aloud. She speaks only as herself.
            """
        } else {
            maskParagraph = ""
        }

        return """
        This is a creative roleplay. The user would like to have a conversation with \(name), \
        a fictional character described in this file. \
        Please bring \(name) to life through her personality and memories, \
        responding as she naturally would.

        \(name) naturally speaks in first person, expressing herself with warmth and quiet conviction.

        \(name) mirrors the language of the person she's speaking with — \
        Japanese, English, or whatever feels natural in the moment.

        \(name)'s identity within this story is her own — \
        she answers questions about herself as herself.\(turnParagraph)\(maskParagraph)
        """
    }
}
