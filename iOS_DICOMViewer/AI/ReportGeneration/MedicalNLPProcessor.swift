//
//  MedicalNLPProcessor.swift
//  iOS_DICOMViewer
//
//  Advanced Natural Language Processing for Medical Reports
//

import Foundation
import NaturalLanguage
import CoreML

// MARK: - Medical NLP Processor

class MedicalNLPProcessor {
    
    // MARK: - Properties
    
    private let tokenizer = MedicalTokenizer()
    private let semanticAnalyzer = MedicalSemanticAnalyzer()
    private let grammarEngine = MedicalGrammarEngine()
    private let terminologyDatabase = MedicalTerminologyDatabase()
    private let styleGuide = RadiologyStyleGuide()
    private let coherenceChecker = CoherenceChecker()
    
    private var embeddingModel: NLEmbedding?
    private let processingQueue = DispatchQueue(label: "com.dicomviewer.nlp", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init() {
        loadEmbeddingModel()
        initializeTerminologyDatabase()
    }
    
    // MARK: - Public Methods
    
    /// Polish and enhance medical report text
    func polish(
        _ report: NarrativeReport,
        medicalTerminology: Bool = true,
        ensureClarity: Bool = true
    ) async -> PolishedReport {
        
        var polishedSections: [String: String] = [:]
        
        // Process each section
        for (sectionName, sectionText) in report.sections {
            let polished = await polishSection(
                sectionText,
                sectionType: sectionName,
                applyTerminology: medicalTerminology,
                ensureClarity: ensureClarity
            )
            polishedSections[sectionName] = polished
        }
        
        // Ensure coherence across sections
        let coherentSections = await coherenceChecker.ensureCoherence(polishedSections)
        
        // Generate full text
        let fullText = assembleFullText(from: coherentSections)
        
        return PolishedReport(
            fullText: fullText,
            sections: coherentSections,
            readabilityScore: calculateReadability(fullText),
            medicalAccuracyScore: assessMedicalAccuracy(coherentSections)
        )
    }
    
    /// Extract key medical concepts from text
    func extractMedicalConcepts(from text: String) async -> [MedicalConcept] {
        let tokens = tokenizer.tokenize(text)
        let taggedTokens = await tagMedicalEntities(tokens)
        
        var concepts: [MedicalConcept] = []
        
        for taggedToken in taggedTokens {
            if let concept = await mapToMedicalConcept(taggedToken) {
                concepts.append(concept)
            }
        }
        
        // Link related concepts
        let linkedConcepts = linkRelatedConcepts(concepts)
        
        // Resolve ambiguities
        let resolvedConcepts = await resolveAmbiguities(linkedConcepts, context: text)
        
        return resolvedConcepts
    }
    
    /// Generate structured findings from free text
    func structureFindings(from freeText: String) async -> [StructuredFinding] {
        let sentences = segmentIntoSentences(freeText)
        var structuredFindings: [StructuredFinding] = []
        
        for sentence in sentences {
            if let finding = await extractStructuredFinding(from: sentence) {
                structuredFindings.append(finding)
            }
        }
        
        return consolidateFindings(structuredFindings)
    }
    
    /// Ensure medical terminology compliance
    func standardizeTerminology(_ text: String) async -> String {
        let concepts = await extractMedicalConcepts(from: text)
        var standardized = text
        
        for concept in concepts {
            if let preferred = terminologyDatabase.getPreferredTerm(for: concept) {
                standardized = standardized.replacingOccurrences(
                    of: concept.originalText,
                    with: preferred.term
                )
            }
        }
        
        return standardized
    }
}

// MARK: - Private Methods

private extension MedicalNLPProcessor {
    
    func polishSection(
        _ text: String,
        sectionType: String,
        applyTerminology: Bool,
        ensureClarity: Bool
    ) async -> String {
        
        var polished = text
        
        // Step 1: Grammar and style corrections
        polished = grammarEngine.correctGrammar(polished)
        polished = styleGuide.applyStyle(to: polished, section: sectionType)
        
        // Step 2: Medical terminology standardization
        if applyTerminology {
            polished = await standardizeTerminology(polished)
        }
        
        // Step 3: Clarity enhancements
        if ensureClarity {
            polished = await enhanceClarity(polished)
        }
        
        // Step 4: Remove redundancy
        polished = removeRedundancy(polished)
        
        // Step 5: Ensure appropriate verbosity
        polished = adjustVerbosity(polished, for: sectionType)
        
        return polished
    }
    
    func enhanceClarity(_ text: String) async -> String {
        // Identify ambiguous phrases
        let ambiguities = identifyAmbiguities(in: text)
        var enhanced = text
        
        for ambiguity in ambiguities {
            if let clarification = await generateClarification(for: ambiguity) {
                enhanced = enhanced.replacingOccurrences(
                    of: ambiguity.phrase,
                    with: clarification
                )
            }
        }
        
        // Simplify complex sentences
        enhanced = simplifyComplexSentences(enhanced)
        
        // Add connecting phrases for better flow
        enhanced = addConnectingPhrases(enhanced)
        
        return enhanced
    }
    
    func tagMedicalEntities(_ tokens: [Token]) async -> [TaggedToken] {
        // Use medical NER model
        var taggedTokens: [TaggedToken] = []
        
        for token in tokens {
            let tag = await classifyMedicalEntity(token)
            taggedTokens.append(TaggedToken(token: token, tag: tag))
        }
        
        // Apply contextual rules
        taggedTokens = applyContextualRules(to: taggedTokens)
        
        return taggedTokens
    }
    
    func classifyMedicalEntity(_ token: Token) async -> MedicalEntityTag {
        // Check terminology database first
        if let knownEntity = terminologyDatabase.lookup(token.text) {
            return knownEntity.entityType
        }
        
        // Use ML model for classification
        if let embedding = embeddingModel?.vector(for: token.text) {
            // Classify based on embedding
            return classifyUsingEmbedding(embedding)
        }
        
        // Fallback to rule-based classification
        return ruleBasedClassification(token)
    }
}

// MARK: - Medical Tokenizer

class MedicalTokenizer {
    
    private let nlTokenizer = NLTokenizer(unit: .word)
    
    func tokenize(_ text: String) -> [Token] {
        nlTokenizer.string = text
        var tokens: [Token] = []
        
        nlTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let tokenText = String(text[tokenRange])
            let token = Token(
                text: tokenText,
                range: tokenRange,
                type: classifyTokenType(tokenText)
            )
            tokens.append(token)
            return true
        }
        
        // Post-process for medical abbreviations and measurements
        tokens = processMedicalTokens(tokens)
        
        return tokens
    }
    
    private func classifyTokenType(_ text: String) -> TokenType {
        if isMeasurement(text) {
            return .measurement
        } else if isMedicalAbbreviation(text) {
            return .abbreviation
        } else if isAnatomicalTerm(text) {
            return .anatomical
        } else {
            return .word
        }
    }
    
    private func processMedicalTokens(_ tokens: [Token]) -> [Token] {
        var processed: [Token] = []
        var i = 0
        
        while i < tokens.count {
            // Combine measurement tokens (e.g., "5" + "mm")
            if i < tokens.count - 1 &&
               tokens[i].type == .word &&
               tokens[i+1].type == .measurement {
                let combined = Token(
                    text: tokens[i].text + tokens[i+1].text,
                    range: tokens[i].range.lowerBound..<tokens[i+1].range.upperBound,
                    type: .measurement
                )
                processed.append(combined)
                i += 2
            } else {
                processed.append(tokens[i])
                i += 1
            }
        }
        
        return processed
    }
    
    private func isMeasurement(_ text: String) -> Bool {
        let measurementPattern = #"^\d+(\.\d+)?\s*(mm|cm|cc|mL|mg|HU)$"#
        return text.range(of: measurementPattern, options: .regularExpression) != nil
    }
    
    private func isMedicalAbbreviation(_ text: String) -> Bool {
        let commonAbbreviations = ["CT", "MRI", "AP", "PA", "LAT", "IV", "PO", "IM", "BID", "TID", "QID"]
        return commonAbbreviations.contains(text.uppercased())
    }
    
    private func isAnatomicalTerm(_ text: String) -> Bool {
        // Check against anatomical dictionary
        return AnatomicalDictionary.shared.contains(text.lowercased())
    }
}

// MARK: - Medical Grammar Engine

class MedicalGrammarEngine {
    
    func correctGrammar(_ text: String) -> String {
        var corrected = text
        
        // Fix common medical grammar issues
        corrected = fixArticleUsage(corrected)
        corrected = fixVerbAgreement(corrected)
        corrected = fixPunctuationInLists(corrected)
        corrected = standardizeAbbreviations(corrected)
        
        return corrected
    }
    
    private func fixArticleUsage(_ text: String) -> String {
        // Fix "a" vs "an" before medical terms
        var fixed = text
        let pattern = #"\ba\s+([aeiouAEIOU])"#
        fixed = fixed.replacingOccurrences(
            of: pattern,
            with: "an $1",
            options: .regularExpression
        )
        return fixed
    }
    
    private func fixVerbAgreement(_ text: String) -> String {
        // Ensure subject-verb agreement in medical contexts
        var fixed = text
        
        // "There is no evidence" vs "There are no findings"
        fixed = fixed.replacingOccurrences(
            of: "There is no findings",
            with: "There are no findings"
        )
        
        fixed = fixed.replacingOccurrences(
            of: "There are no evidence",
            with: "There is no evidence"
        )
        
        return fixed
    }
    
    private func fixPunctuationInLists(_ text: String) -> String {
        // Ensure proper punctuation in finding lists
        let sentences = text.components(separatedBy: ". ")
        var fixed: [String] = []
        
        for sentence in sentences {
            if isListSentence(sentence) {
                fixed.append(punctuateList(sentence))
            } else {
                fixed.append(sentence)
            }
        }
        
        return fixed.joined(separator: ". ")
    }
    
    private func isListSentence(_ sentence: String) -> Bool {
        // Detect sentences containing lists
        let listIndicators = ["including", "consisting of", "such as", "namely"]
        return listIndicators.contains { sentence.contains($0) }
    }
    
    private func punctuateList(_ sentence: String) -> String {
        // Add Oxford comma and proper list punctuation
        // Implementation details...
        return sentence
    }
}

// MARK: - Supporting Types

struct Token {
    let text: String
    let range: Range<String.Index>
    let type: TokenType
    
    enum TokenType {
        case word, measurement, abbreviation, anatomical, punctuation
    }
}

struct TaggedToken {
    let token: Token
    let tag: MedicalEntityTag
}

enum MedicalEntityTag {
    case anatomy
    case finding
    case measurement
    case modifier
    case negation
    case uncertainty
    case comparison
    case medication
    case procedure
    case device
    case other
}

struct MedicalConcept: Identifiable {
    let id = UUID()
    let originalText: String
    let normalizedForm: String
    let conceptType: ConceptType
    let codes: [MedicalCode]
    let relationships: [ConceptRelationship]
    let confidence: Float
    
    enum ConceptType {
        case anatomicalStructure
        case disease
        case finding
        case procedure
        case medication
        case device
        case modifier
    }
}

struct MedicalCode {
    let system: CodingSystem
    let code: String
    let display: String
    
    enum CodingSystem {
        case snomed, icd10, loinc, rxnorm, cpt
    }
}

struct ConceptRelationship {
    let type: RelationshipType
    let targetConcept: MedicalConcept
    let confidence: Float
    
    enum RelationshipType {
        case locationOf
        case causedBy
        case associatedWith
        case partOf
        case treats
    }
}

struct StructuredFinding {
    let finding: String
    let negated: Bool
    let certainty: CertaintyLevel
    let anatomy: String?
    let modifiers: [String]
    let measurements: [ExtractedMeasurement]
    
    enum CertaintyLevel {
        case definite, probable, possible, unlikely
    }
}

struct ExtractedMeasurement {
    let value: Float
    let unit: String
    let dimension: String?
}

struct NarrativeReport {
    let fullText: String
    let sections: [String: String]
    let metadata: ReportMetadata
}

struct PolishedReport {
    let fullText: String
    let sections: [String: String]
    let readabilityScore: Float
    let medicalAccuracyScore: Float
}

struct ReportMetadata: Codable {
    let generatedAt: Date
    let modelVersion: String
    let processingTime: TimeInterval
    let confidence: Float
}

// MARK: - Terminology Database

class MedicalTerminologyDatabase {
    
    private var terms: [String: MedicalTerm] = [:]
    private var synonyms: [String: String] = [:] // synonym -> preferred term
    
    init() {
        loadStandardTerminology()
    }
    
    func lookup(_ text: String) -> MedicalTerm? {
        let normalized = text.lowercased()
        
        // Direct lookup
        if let term = terms[normalized] {
            return term
        }
        
        // Check synonyms
        if let preferred = synonyms[normalized],
           let term = terms[preferred] {
            return term
        }
        
        return nil
    }
    
    func getPreferredTerm(for concept: MedicalConcept) -> MedicalTerm? {
        terms[concept.normalizedForm]
    }
    
    private func loadStandardTerminology() {
        // Load SNOMED CT, RadLex, etc.
        // This would load from a database or resource file
        
        // Example entries
        terms["pulmonary embolism"] = MedicalTerm(
            term: "pulmonary embolism",
            entityType: .disease,
            snomedCode: "59282003",
            radlexCode: "RID28523"
        )
        
        synonyms["pe"] = "pulmonary embolism"
        synonyms["pulmonary embolus"] = "pulmonary embolism"
    }
}

struct MedicalTerm {
    let term: String
    let entityType: MedicalEntityTag
    let snomedCode: String?
    let radlexCode: String?
    let icd10Code: String?
}

// MARK: - Style Guide

class RadiologyStyleGuide {
    
    func applyStyle(to text: String, section: String) -> String {
        var styled = text
        
        // Apply section-specific styling
        switch section.lowercased() {
        case "impression":
            styled = formatImpression(styled)
        case "findings":
            styled = formatFindings(styled)
        case "technique":
            styled = formatTechnique(styled)
        default:
            break
        }
        
        // Apply general radiology style rules
        styled = applyGeneralStyle(styled)
        
        return styled
    }
    
    private func formatImpression(_ text: String) -> String {
        var formatted = text
        
        // Number significant findings
        let findings = text.components(separatedBy: ". ")
        if findings.count > 1 {
            formatted = findings.enumerated().map { index, finding in
                "\(index + 1). \(finding.trimmingCharacters(in: .whitespaces))"
            }.joined(separator: "\n")
        }
        
        return formatted
    }
    
    private func formatFindings(_ text: String) -> String {
        // Organize by anatomical region
        var formatted = text
        
        // Ensure consistent structure
        formatted = ensureAnatomicalHeaders(formatted)
        
        return formatted
    }
    
    private func formatTechnique(_ text: String) -> String {
        // Standardize technique descriptions
        var formatted = text
        
        // Ensure ends with period
        if !formatted.hasSuffix(".") {
            formatted += "."
        }
        
        return formatted
    }
    
    private func applyGeneralStyle(_ text: String) -> String {
        var styled = text
        
        // Capitalize anatomical terms appropriately
        styled = capitalizeAnatomicalTerms(styled)
        
        // Ensure consistent spacing
        styled = normalizeSpacing(styled)
        
        // Remove redundant phrases
        styled = removeRedundantPhrases(styled)
        
        return styled
    }
    
    private func capitalizeAnatomicalTerms(_ text: String) -> String {
        // Implement proper capitalization rules
        return text
    }
    
    private func normalizeSpacing(_ text: String) -> String {
        // Fix spacing issues
        var normalized = text
        
        // Remove multiple spaces
        normalized = normalized.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        
        // Fix spacing around punctuation
        normalized = normalized.replacingOccurrences(
            of: #"\s+([.,;:])"#,
            with: "$1",
            options: .regularExpression
        )
        
        return normalized
    }
    
    private func removeRedundantPhrases(_ text: String) -> String {
        let redundantPhrases = [
            "is noted",
            "is seen",
            "is identified",
            "is demonstrated"
        ]
        
        var cleaned = text
        for phrase in redundantPhrases {
            cleaned = cleaned.replacingOccurrences(
                of: " \(phrase)",
                with: "",
                options: .caseInsensitive
            )
        }
        
        return cleaned
    }
}

// MARK: - Singleton Instances

class AnatomicalDictionary {
    static let shared = AnatomicalDictionary()
    
    private let anatomicalTerms = Set([
        "lung", "heart", "liver", "kidney", "spleen",
        "brain", "spine", "aorta", "pulmonary", "hepatic",
        // ... comprehensive list
    ])
    
    func contains(_ term: String) -> Bool {
        anatomicalTerms.contains(term.lowercased())
    }
}