//
//  TemplateEngine.swift
//  iOS_DICOMViewer
//
//  Advanced Medical Report Template Engine with Dynamic Generation
//

import Foundation
import NaturalLanguage

// MARK: - Template Engine

class TemplateEngine {
    
    // MARK: - Properties
    
    private var templates: [String: ReportTemplate] = [:]
    private let customizer = TemplateCustomizer()
    private let validator = TemplateValidator()
    
    // MARK: - Initialization
    
    init() {
        loadBuiltInTemplates()
        loadCustomTemplates()
    }
    
    // MARK: - Template Management
    
    func getTemplate(for type: ReportType, modality: String) -> ReportTemplate {
        let key = "\(type.rawValue)_\(modality)"
        
        if let customTemplate = templates[key] {
            return customTemplate
        }
        
        // Fall back to general template for the report type
        if let generalTemplate = templates[type.rawValue] {
            return customizer.adaptForModality(generalTemplate, modality: modality)
        }
        
        // Create default template if none exists
        return createDefaultTemplate(for: type, modality: modality)
    }
    
    // MARK: - Built-in Templates
    
    private func loadBuiltInTemplates() {
        // Chest X-Ray Template
        templates["Diagnostic_CR"] = ReportTemplate(
            id: "chest_xray_diagnostic",
            name: "Chest X-Ray Diagnostic",
            reportType: .diagnostic,
            modality: "CR",
            sections: [
                TemplateSection(
                    name: "Technique",
                    template: "{{views}} views of the chest were obtained{{positioning_note}}.",
                    required: true,
                    order: 1
                ),
                TemplateSection(
                    name: "Findings",
                    template: """
                    LUNGS: {{lung_findings|default:'Clear and expanded bilaterally.'}}
                    HEART: {{heart_size|default:'Normal in size.'}} {{cardiac_findings}}
                    MEDIASTINUM: {{mediastinal_findings|default:'Normal mediastinal contours.'}}
                    BONES: {{bone_findings|default:'No acute osseous abnormality.'}}
                    SOFT TISSUES: {{soft_tissue_findings|default:'Unremarkable.'}}
                    """,
                    required: true,
                    order: 2
                ),
                TemplateSection(
                    name: "Impression",
                    template: "{{primary_impression}}{{additional_findings}}",
                    required: true,
                    order: 3
                )
            ],
            variables: [
                TemplateVariable(name: "views", type: .selection(["PA and lateral", "PA only", "Portable AP"]), required: true),
                TemplateVariable(name: "positioning_note", type: .text, required: false)
            ],
            phraseLibrary: ChestXRayPhrases(),
            validationRules: [
                ValidationRule(field: "lung_findings", rule: .notEmpty),
                ValidationRule(field: "primary_impression", rule: .minimumLength(10))
            ]
        )
        
        // CT Chest Template
        templates["Diagnostic_CT"] = ReportTemplate(
            id: "ct_chest_diagnostic",
            name: "CT Chest Diagnostic",
            reportType: .diagnostic,
            modality: "CT",
            sections: [
                TemplateSection(
                    name: "Technique",
                    template: """
                    {{contrast_type|default:'Non-contrast'}} CT chest was performed with {{slice_thickness}}mm slices
                    from {{scan_range|default:'lung apices to adrenal glands'}}.
                    {{reconstruction_note}}
                    {{dose_note}}
                    """,
                    required: true,
                    order: 1
                ),
                TemplateSection(
                    name: "Findings",
                    template: """
                    LUNGS:
                    {{lung_parenchyma}}
                    {{airways}}
                    {{pleura}}
                    
                    MEDIASTINUM:
                    Heart: {{heart_findings|default:'Normal size and configuration.'}}
                    Great vessels: {{vessel_findings|default:'Normal caliber.'}}
                    Lymph nodes: {{lymph_node_findings|default:'No pathologically enlarged lymph nodes.'}}
                    
                    BONES AND SOFT TISSUES:
                    {{bone_findings}}
                    {{soft_tissue_findings}}
                    
                    UPPER ABDOMEN:
                    {{upper_abdomen_findings|default:'Visualized portions unremarkable.'}}
                    """,
                    required: true,
                    order: 2
                )
            ],
            variables: [
                TemplateVariable(name: "contrast_type", type: .selection(["Non-contrast", "Contrast-enhanced", "CT angiography"]), required: true),
                TemplateVariable(name: "slice_thickness", type: .number(range: 0.5...5.0), required: true)
            ],
            phraseLibrary: CTChestPhrases(),
            includeNegativeFindings: true
        )
        
        // MRI Brain Template
        templates["Diagnostic_MR"] = createMRIBrainTemplate()
        
        // Emergency Templates
        templates["Emergency_CT"] = createEmergencyCTTemplate()
    }
    
    // MARK: - Dynamic Template Creation
    
    func createDynamicTemplate(
        from findings: [MedicalFinding],
        reportType: ReportType,
        modality: String
    ) -> ReportTemplate {
        
        let analyzer = FindingsPatternAnalyzer()
        let patterns = analyzer.identifyPatterns(in: findings)
        
        var sections: [TemplateSection] = []
        
        // Always include technique
        sections.append(createTechniqueSection(for: modality))
        
        // Dynamic findings sections based on identified patterns
        for pattern in patterns {
            sections.append(createFindingsSection(for: pattern, modality: modality))
        }
        
        // Impression section
        sections.append(createImpressionSection(patterns: patterns))
        
        // Generate appropriate variables
        let variables = generateTemplateVariables(for: patterns, modality: modality)
        
        return ReportTemplate(
            id: UUID().uuidString,
            name: "Dynamic \(reportType.rawValue) Template",
            reportType: reportType,
            modality: modality,
            sections: sections,
            variables: variables,
            phraseLibrary: DynamicPhraseLibrary(patterns: patterns),
            includeNegativeFindings: reportType == .screening
        )
    }
}

// MARK: - Report Template

struct ReportTemplate: Codable {
    let id: String
    let name: String
    let reportType: ReportType
    let modality: String
    let sections: [TemplateSection]
    let variables: [TemplateVariable]
    let phraseLibrary: PhraseLibrary
    let validationRules: [ValidationRule]
    let includeNegativeFindings: Bool
    let customPhrases: [String: String]
    
    init(
        id: String,
        name: String,
        reportType: ReportType,
        modality: String,
        sections: [TemplateSection],
        variables: [TemplateVariable] = [],
        phraseLibrary: PhraseLibrary = StandardPhraseLibrary(),
        validationRules: [ValidationRule] = [],
        includeNegativeFindings: Bool = false,
        customPhrases: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.reportType = reportType
        self.modality = modality
        self.sections = sections
        self.variables = variables
        self.phraseLibrary = phraseLibrary
        self.validationRules = validationRules
        self.includeNegativeFindings = includeNegativeFindings
        self.customPhrases = customPhrases
    }
}

struct TemplateSection: Codable {
    let name: String
    let template: String
    let required: Bool
    let order: Int
    let subsections: [TemplateSection]?
    
    init(name: String, template: String, required: Bool = true, order: Int, subsections: [TemplateSection]? = nil) {
        self.name = name
        self.template = template
        self.required = required
        self.order = order
        self.subsections = subsections
    }
    
    func render(with variables: [String: Any]) -> String {
        TemplateRenderer.render(template: template, variables: variables)
    }
}

struct TemplateVariable: Codable {
    let name: String
    let type: VariableType
    let required: Bool
    let defaultValue: String?
    let validation: ValidationRule?
    
    init(name: String, type: VariableType, required: Bool = false, defaultValue: String? = nil, validation: ValidationRule? = nil) {
        self.name = name
        self.type = type
        self.required = required
        self.defaultValue = defaultValue
        self.validation = validation
    }
}

enum VariableType: Codable {
    case text
    case number(range: ClosedRange<Double>)
    case selection([String])
    case multiSelect([String])
    case measurement(unit: String)
    case anatomicalLocation
    case finding
    
    enum CodingKeys: String, CodingKey {
        case type, data
    }
    
    func encode(to encoder: Encoder) throws {
        // Custom encoding implementation
    }
    
    init(from decoder: Decoder) throws {
        // Custom decoding implementation
        self = .text // Placeholder
    }
}

// MARK: - Phrase Libraries

protocol PhraseLibrary: Codable {
    func getPhrase(for finding: FindingType, severity: MedicalFinding.Severity) -> String
    func getNegativePhrase(for anatomy: AnatomicalRegion) -> String
    func getComparisonPhrase(change: ChangeType) -> String
    func getTechniquePhrases(modality: String) -> [String]
}

struct ChestXRayPhrases: PhraseLibrary {
    func getPhrase(for finding: FindingType, severity: MedicalFinding.Severity) -> String {
        switch (finding, severity) {
        case (.consolidation, .mild):
            return "Patchy airspace opacity"
        case (.consolidation, .moderate):
            return "Consolidation"
        case (.consolidation, .severe):
            return "Dense consolidation"
        case (.effusion, .minimal):
            return "Trace pleural effusion"
        case (.effusion, .mild):
            return "Small pleural effusion"
        case (.effusion, .moderate):
            return "Moderate pleural effusion"
        case (.effusion, .severe):
            return "Large pleural effusion"
        case (.nodule, _):
            return "\(severity.rawValue)mm nodule"
        default:
            return "\(severity) \(finding.displayName.lowercased())"
        }
    }
    
    func getNegativePhrase(for anatomy: AnatomicalRegion) -> String {
        switch anatomy {
        case .chest:
            return "No acute cardiopulmonary process"
        case .head:
            return "No acute intracranial abnormality"
        default:
            return "No acute findings"
        }
    }
    
    func getComparisonPhrase(change: ChangeType) -> String {
        switch change {
        case .improved:
            return "Interval improvement"
        case .stable:
            return "Stable appearance"
        case .progressed:
            return "Interval progression"
        case .new:
            return "New since prior examination"
        case .resolved:
            return "Previously noted finding has resolved"
        }
    }
    
    func getTechniquePhrases(modality: String) -> [String] {
        ["PA and lateral views", "Portable AP view", "Single frontal view"]
    }
}

enum ChangeType: String, Codable {
    case improved, stable, progressed, new, resolved
}

// MARK: - Template Renderer

class TemplateRenderer {
    static func render(template: String, variables: [String: Any]) -> String {
        var rendered = template
        
        // Find all variables in format {{variable_name|options}}
        let pattern = #"\{\{([^}]+)\}\}"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template))
        
        // Process matches in reverse order to maintain string indices
        for match in matches.reversed() {
            guard let range = Range(match.range, in: template) else { continue }
            let variableExpression = String(template[range])
            let processed = processVariable(variableExpression, variables: variables)
            rendered.replaceSubrange(range, with: processed)
        }
        
        return rendered
    }
    
    private static func processVariable(_ expression: String, variables: [String: Any]) -> String {
        // Remove {{ and }}
        let cleaned = expression
            .replacingOccurrences(of: "{{", with: "")
            .replacingOccurrences(of: "}}", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        // Parse variable name and options
        let parts = cleaned.split(separator: "|")
        let variableName = String(parts[0])
        
        // Get variable value
        let value = variables[variableName]
        
        // Handle default values
        if value == nil || (value as? String)?.isEmpty == true {
            if parts.count > 1 {
                let defaultPart = parts[1]
                if defaultPart.hasPrefix("default:") {
                    let defaultValue = defaultPart
                        .replacingOccurrences(of: "default:", with: "")
                        .replacingOccurrences(of: "'", with: "")
                    return defaultValue
                }
            }
            return ""
        }
        
        // Convert value to string
        return String(describing: value!)
    }
}

// MARK: - Template Customizer

class TemplateCustomizer {
    func adaptForModality(_ template: ReportTemplate, modality: String) -> ReportTemplate {
        var adapted = template
        
        // Adapt sections based on modality
        adapted.sections = template.sections.map { section in
            var adaptedSection = section
            
            // Modality-specific adjustments
            switch modality {
            case "CT":
                if section.name == "Technique" {
                    adaptedSection.template = addCTSpecificTechnique(to: section.template)
                }
            case "MR":
                if section.name == "Technique" {
                    adaptedSection.template = addMRSpecificTechnique(to: section.template)
                }
            default:
                break
            }
            
            return adaptedSection
        }
        
        return adapted
    }
    
    private func addCTSpecificTechnique(to template: String) -> String {
        template + "\nRadiation dose: {{ctdi_vol}} mGy, DLP: {{dlp}} mGy.cm"
    }
    
    private func addMRSpecificTechnique(to template: String) -> String {
        template + "\nSequences obtained: {{sequences|default:'T1, T2, FLAIR, DWI, ADC'}}"
    }
}

// MARK: - Validation

struct ValidationRule: Codable {
    let field: String
    let rule: ValidationType
    let errorMessage: String?
    
    init(field: String, rule: ValidationType, errorMessage: String? = nil) {
        self.field = field
        self.rule = rule
        self.errorMessage = errorMessage
    }
}

enum ValidationType: Codable {
    case notEmpty
    case minimumLength(Int)
    case maximumLength(Int)
    case regex(String)
    case custom(String) // Function name to call
    
    func validate(_ value: String) -> Bool {
        switch self {
        case .notEmpty:
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .minimumLength(let length):
            return value.count >= length
        case .maximumLength(let length):
            return value.count <= length
        case .regex(let pattern):
            return value.range(of: pattern, options: .regularExpression) != nil
        case .custom:
            return true // Would call custom validation function
        }
    }
}

class TemplateValidator {
    func validate(_ report: String, using rules: [ValidationRule]) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        for rule in rules {
            // Extract field value from report
            let fieldValue = extractFieldValue(field: rule.field, from: report)
            
            if !rule.rule.validate(fieldValue) {
                errors.append(ValidationError(
                    field: rule.field,
                    message: rule.errorMessage ?? "Validation failed for \(rule.field)",
                    severity: .error
                ))
            }
        }
        
        return errors
    }
    
    private func extractFieldValue(field: String, from report: String) -> String {
        // Implementation to extract field values from report
        return ""
    }
}

struct ValidationError {
    let field: String
    let message: String
    let severity: Severity
    
    enum Severity {
        case warning, error
    }
}