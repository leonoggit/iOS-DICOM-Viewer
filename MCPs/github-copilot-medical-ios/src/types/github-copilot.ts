export interface GitHubCopilotConfig {
  apiKey?: string;
  modelFamily: 'gpt-4' | 'gpt-3.5-turbo' | 'codex';
  medicalImagingContext: boolean;
  iosDevContext: boolean;
  swiftOptimizations: boolean;
  dicomStandards: string[];
}

export interface MedicalImagingPrompt {
  modality?: 'CT' | 'MR' | 'X-Ray' | 'Ultrasound' | 'PET' | 'SPECT' | 'Mammography';
  clinicalContext?: string;
  technicalRequirements?: string[];
  complianceStandards?: string[];
}

export interface IOSDevPrompt {
  swiftVersion?: string;
  deploymentTarget?: string;
  frameworks?: string[];
  architecturalPattern?: 'MVC' | 'MVP' | 'MVVM' | 'VIPER' | 'Coordinator';
  performance?: 'memory' | 'cpu' | 'gpu' | 'network';
}

export interface CopilotSuggestion {
  code: string;
  explanation: string;
  medicalCompliance?: {
    standard: string;
    level: 'basic' | 'enhanced' | 'clinical';
    auditTrail: boolean;
  };
  iosOptimization?: {
    memoryEfficient: boolean;
    metalCompatible: boolean;
    backgroundProcessing: boolean;
  };
  bestPractices: string[];
  alternativeApproaches?: string[];
}

export interface CodeGenerationRequest {
  prompt: string;
  context: {
    medical?: MedicalImagingPrompt;
    ios?: IOSDevPrompt;
    existingCode?: string;
    projectStructure?: string[];
  };
  preferences: {
    verbosity: 'minimal' | 'detailed' | 'comprehensive';
    includeTests: boolean;
    includeDocumentation: boolean;
    optimizeFor: 'readability' | 'performance' | 'maintainability';
  };
}