/**
 * Medical Terminology Lookup
 * Provides lookup and validation for medical imaging terminology
 */

import { MedicalTerminology, Modality } from '../types/dicom.js';

export interface TerminologyLookupResult {
  term: string;
  definitions: MedicalTerminology[];
  relatedTerms: string[];
  category: TerminologyCategory;
  confidence: number;
}

export enum TerminologyCategory {
  ANATOMY = 'anatomy',
  MODALITY = 'modality',
  PROCEDURE = 'procedure',
  PATHOLOGY = 'pathology',
  MEASUREMENT = 'measurement',
  TECHNIQUE = 'technique',
  EQUIPMENT = 'equipment',
  CONTRAST = 'contrast',
  ORIENTATION = 'orientation',
  PROTOCOL = 'protocol'
}

export interface AnatomicalRegion {
  code: string;
  name: string;
  category: string;
  bodyPart: string;
  synonyms: string[];
  relatedRegions: string[];
}

export interface ImagingProcedure {
  code: string;
  name: string;
  modality: string;
  description: string;
  indications: string[];
  contraindications: string[];
  preparation: string[];
}

export class MedicalTerminologyLookup {
  private anatomicalTerms: Map<string, AnatomicalRegion> = new Map();
  private procedureTerms: Map<string, ImagingProcedure> = new Map();
  private modalityTerms: Map<string, MedicalTerminology> = new Map();
  private generalTerms: Map<string, MedicalTerminology> = new Map();

  constructor() {
    this.initializeTerminologyDatabase();
  }

  /**
   * Look up medical terminology
   */
  lookupTerm(term: string): TerminologyLookupResult {
    const normalizedTerm = this.normalizeTerm(term);
    const results: MedicalTerminology[] = [];
    let category = TerminologyCategory.ANATOMY;
    let confidence = 0;

    // Search in different terminology databases
    const anatomicalMatch = this.searchAnatomical(normalizedTerm);
    const procedureMatch = this.searchProcedures(normalizedTerm);
    const modalityMatch = this.searchModalities(normalizedTerm);
    const generalMatch = this.searchGeneral(normalizedTerm);

    // Combine results and determine best match
    if (anatomicalMatch) {
      results.push(this.anatomicalToTerminology(anatomicalMatch));
      category = TerminologyCategory.ANATOMY;
      confidence = 0.9;
    }

    if (procedureMatch) {
      results.push(this.procedureToTerminology(procedureMatch));
      if (confidence < 0.8) {
        category = TerminologyCategory.PROCEDURE;
        confidence = 0.8;
      }
    }

    if (modalityMatch) {
      results.push(modalityMatch);
      if (confidence < 0.7) {
        category = TerminologyCategory.MODALITY;
        confidence = 0.7;
      }
    }

    if (generalMatch) {
      results.push(generalMatch);
      if (confidence < 0.6) {
        confidence = 0.6;
      }
    }

    // Generate related terms
    const relatedTerms = this.findRelatedTerms(normalizedTerm, category);

    return {
      term: normalizedTerm,
      definitions: results,
      relatedTerms,
      category,
      confidence
    };
  }

  /**
   * Validate DICOM terminology codes
   */
  validateTerminologyCode(code: string, scheme: string): {
    isValid: boolean;
    meaning?: string;
    scheme: string;
    category?: string;
  } {
    // Common DICOM coding schemes
    const validationResult = {
      isValid: false,
      scheme,
      meaning: undefined as string | undefined,
      category: undefined as string | undefined
    };

    switch (scheme.toUpperCase()) {
      case 'SNM3':
      case 'SNOMED':
        validationResult.isValid = this.validateSNOMEDCode(code);
        break;
      case 'DCM':
        validationResult.isValid = this.validateDCMCode(code);
        break;
      case 'UCUM':
        validationResult.isValid = this.validateUCUMCode(code);
        break;
      case 'ICD10':
        validationResult.isValid = this.validateICD10Code(code);
        break;
      default:
        validationResult.isValid = false;
    }

    if (validationResult.isValid) {
      const terminology = this.lookupCodeInScheme(code, scheme);
      if (terminology) {
        validationResult.meaning = terminology.meaning;
        validationResult.category = terminology.category;
      }
    }

    return validationResult;
  }

  /**
   * Get anatomical region suggestions
   */
  getAnatomicalRegions(bodyPart?: string): AnatomicalRegion[] {
    const regions = Array.from(this.anatomicalTerms.values());
    
    if (bodyPart) {
      return regions.filter(region => 
        region.bodyPart.toLowerCase().includes(bodyPart.toLowerCase())
      );
    }
    
    return regions;
  }

  /**
   * Get imaging procedures for modality
   */
  getImagingProcedures(modality?: string): ImagingProcedure[] {
    const procedures = Array.from(this.procedureTerms.values());
    
    if (modality) {
      return procedures.filter(proc => 
        proc.modality.toLowerCase() === modality.toLowerCase()
      );
    }
    
    return procedures;
  }

  /**
   * Suggest appropriate imaging protocols
   */
  suggestImagingProtocol(indication: string, modality: string): {
    protocol: string;
    description: string;
    parameters: string[];
    contraindications: string[];
  }[] {
    const suggestions: {
      protocol: string;
      description: string;
      parameters: string[];
      contraindications: string[];
    }[] = [];

    // Basic protocol suggestions based on indication and modality
    const protocolDatabase = this.getProtocolDatabase();
    
    for (const protocol of protocolDatabase) {
      if (protocol.modality === modality && 
          protocol.indications.some(ind => 
            indication.toLowerCase().includes(ind.toLowerCase())
          )) {
        suggestions.push({
          protocol: protocol.name,
          description: protocol.description,
          parameters: protocol.parameters || [],
          contraindications: protocol.contraindications
        });
      }
    }

    return suggestions;
  }

  /**
   * Initialize terminology database
   */
  private initializeTerminologyDatabase(): void {
    this.initializeAnatomicalTerms();
    this.initializeProcedureTerms();
    this.initializeModalityTerms();
    this.initializeGeneralTerms();
  }

  /**
   * Initialize anatomical terminology
   */
  private initializeAnatomicalTerms(): void {
    const anatomicalData: AnatomicalRegion[] = [
      {
        code: 'T-D4000',
        name: 'Abdomen',
        category: 'Body Region',
        bodyPart: 'Torso',
        synonyms: ['abdominal cavity', 'belly'],
        relatedRegions: ['pelvis', 'chest']
      },
      {
        code: 'T-11100',
        name: 'Chest',
        category: 'Body Region',
        bodyPart: 'Torso',
        synonyms: ['thorax', 'chest cavity'],
        relatedRegions: ['lungs', 'heart', 'mediastinum']
      },
      {
        code: 'T-A0100',
        name: 'Brain',
        category: 'Organ',
        bodyPart: 'Head',
        synonyms: ['cerebrum', 'cerebral hemisphere'],
        relatedRegions: ['skull', 'head', 'neck']
      },
      {
        code: 'T-32000',
        name: 'Heart',
        category: 'Organ',
        bodyPart: 'Chest',
        synonyms: ['cardiac', 'myocardium'],
        relatedRegions: ['chest', 'mediastinum']
      },
      {
        code: 'T-28000',
        name: 'Lung',
        category: 'Organ',
        bodyPart: 'Chest',
        synonyms: ['pulmonary', 'pneumo'],
        relatedRegions: ['chest', 'pleura']
      }
    ];

    for (const region of anatomicalData) {
      this.anatomicalTerms.set(region.name.toLowerCase(), region);
      for (const synonym of region.synonyms) {
        this.anatomicalTerms.set(synonym.toLowerCase(), region);
      }
    }
  }

  /**
   * Initialize procedure terminology
   */
  private initializeProcedureTerms(): void {
    const procedureData: ImagingProcedure[] = [
      {
        code: 'P1-48000',
        name: 'CT Scan of Head',
        modality: 'CT',
        description: 'Computed tomography examination of the head and brain',
        indications: ['headache', 'trauma', 'stroke', 'tumor'],
        contraindications: ['pregnancy (relative)'],
        preparation: ['remove metal objects', 'patient positioning']
      },
      {
        code: 'P1-48100',
        name: 'MRI Brain',
        modality: 'MR',
        description: 'Magnetic resonance imaging of the brain',
        indications: ['neurological symptoms', 'tumor evaluation', 'multiple sclerosis'],
        contraindications: ['metallic implants', 'pacemaker'],
        preparation: ['MRI safety screening', 'remove metal objects']
      },
      {
        code: 'P1-48200',
        name: 'Chest X-ray',
        modality: 'CR',
        description: 'Plain radiograph of the chest',
        indications: ['cough', 'shortness of breath', 'chest pain'],
        contraindications: ['pregnancy (relative)'],
        preparation: ['remove upper clothing and jewelry']
      }
    ];

    for (const procedure of procedureData) {
      this.procedureTerms.set(procedure.name.toLowerCase(), procedure);
    }
  }

  /**
   * Initialize modality terminology
   */
  private initializeModalityTerms(): void {
    const modalityData: { code: string; name: string; meaning: string; category: string }[] = [
      { code: 'CT', name: 'Computed Tomography', meaning: 'X-ray computed tomography imaging', category: 'imaging_modality' },
      { code: 'MR', name: 'Magnetic Resonance', meaning: 'Magnetic resonance imaging', category: 'imaging_modality' },
      { code: 'US', name: 'Ultrasound', meaning: 'Ultrasound imaging', category: 'imaging_modality' },
      { code: 'XA', name: 'X-Ray Angiography', meaning: 'X-ray angiography imaging', category: 'imaging_modality' },
      { code: 'NM', name: 'Nuclear Medicine', meaning: 'Nuclear medicine imaging', category: 'imaging_modality' },
      { code: 'PT', name: 'Positron Emission Tomography', meaning: 'PET imaging', category: 'imaging_modality' }
    ];

    for (const modality of modalityData) {
      this.modalityTerms.set(modality.code, {
        code: modality.code,
        meaning: modality.meaning,
        codingScheme: 'DCM',
        category: modality.category
      });
      this.modalityTerms.set(modality.name.toLowerCase(), {
        code: modality.code,
        meaning: modality.meaning,
        codingScheme: 'DCM',
        category: modality.category
      });
    }
  }

  /**
   * Initialize general medical terminology
   */
  private initializeGeneralTerms(): void {
    const generalData: MedicalTerminology[] = [
      {
        code: 'HU',
        meaning: 'Hounsfield Unit',
        codingScheme: 'UCUM',
        category: 'measurement',
        definition: 'Unit of measurement for radiodensity in CT imaging'
      },
      {
        code: 'FLAIR',
        meaning: 'Fluid Attenuated Inversion Recovery',
        codingScheme: 'DCM',
        category: 'technique',
        definition: 'MRI pulse sequence that suppresses fluid signal'
      },
      {
        code: 'DWI',
        meaning: 'Diffusion Weighted Imaging',
        codingScheme: 'DCM',
        category: 'technique',
        definition: 'MRI technique sensitive to molecular diffusion'
      },
      {
        code: 'MPRAGE',
        meaning: 'Magnetization Prepared Rapid Gradient Echo',
        codingScheme: 'DCM',
        category: 'technique',
        definition: 'T1-weighted MRI pulse sequence'
      }
    ];

    for (const term of generalData) {
      this.generalTerms.set(term.code.toLowerCase(), term);
      if (term.meaning) {
        this.generalTerms.set(term.meaning.toLowerCase(), term);
      }
    }
  }

  /**
   * Normalize search term
   */
  private normalizeTerm(term: string): string {
    return term.trim().toLowerCase().replace(/[^a-z0-9\s]/gi, '');
  }

  /**
   * Search anatomical terms
   */
  private searchAnatomical(term: string): AnatomicalRegion | null {
    return this.anatomicalTerms.get(term) || null;
  }

  /**
   * Search procedure terms
   */
  private searchProcedures(term: string): ImagingProcedure | null {
    for (const [key, procedure] of this.procedureTerms) {
      if (key.includes(term) || term.includes(key)) {
        return procedure;
      }
    }
    return null;
  }

  /**
   * Search modality terms
   */
  private searchModalities(term: string): MedicalTerminology | null {
    return this.modalityTerms.get(term) || null;
  }

  /**
   * Search general terms
   */
  private searchGeneral(term: string): MedicalTerminology | null {
    for (const [key, terminology] of this.generalTerms) {
      if (key.includes(term) || term.includes(key)) {
        return terminology;
      }
    }
    return null;
  }

  /**
   * Convert anatomical region to terminology
   */
  private anatomicalToTerminology(region: AnatomicalRegion): MedicalTerminology {
    return {
      code: region.code,
      meaning: region.name,
      codingScheme: 'SNM3',
      category: region.category.toLowerCase(),
      definition: `Anatomical region: ${region.name}`,
      synonyms: region.synonyms
    };
  }

  /**
   * Convert procedure to terminology
   */
  private procedureToTerminology(procedure: ImagingProcedure): MedicalTerminology {
    return {
      code: procedure.code,
      meaning: procedure.name,
      codingScheme: 'DCM',
      category: 'procedure',
      definition: procedure.description
    };
  }

  /**
   * Find related terms
   */
  private findRelatedTerms(term: string, category: TerminologyCategory): string[] {
    const related: string[] = [];

    switch (category) {
      case TerminologyCategory.ANATOMY:
        const anatomical = this.anatomicalTerms.get(term);
        if (anatomical) {
          related.push(...anatomical.relatedRegions);
          related.push(...anatomical.synonyms);
        }
        break;
        
      case TerminologyCategory.MODALITY:
        // Add related modalities
        if (term === 'ct') related.push('x-ray', 'radiography');
        if (term === 'mr') related.push('mri', 'magnetic resonance');
        break;
    }

    return related.filter((term, index) => related.indexOf(term) === index); // Remove duplicates
  }

  /**
   * Validate SNOMED codes (simplified)
   */
  private validateSNOMEDCode(code: string): boolean {
    // Basic SNOMED code format validation
    return /^\d{6,18}$/.test(code);
  }

  /**
   * Validate DCM codes (simplified)
   */
  private validateDCMCode(code: string): boolean {
    // Basic DICOM code validation
    return /^[A-Z0-9]+$/.test(code) && code.length <= 16;
  }

  /**
   * Validate UCUM codes (simplified)
   */
  private validateUCUMCode(code: string): boolean {
    // Basic UCUM code validation
    return code.length > 0 && code.length <= 20;
  }

  /**
   * Validate ICD-10 codes (simplified)
   */
  private validateICD10Code(code: string): boolean {
    // Basic ICD-10 format validation
    return /^[A-Z][0-9]{2}(\.[0-9]{1,4})?$/.test(code);
  }

  /**
   * Look up code in specific scheme
   */
  private lookupCodeInScheme(code: string, scheme: string): MedicalTerminology | null {
    // This would typically query a proper terminology database
    // For now, return from our limited local database
    
    if (scheme.toUpperCase() === 'DCM') {
      return this.modalityTerms.get(code) || this.generalTerms.get(code.toLowerCase()) || null;
    }
    
    return null;
  }

  /**
   * Get protocol database
   */
  private getProtocolDatabase(): Array<{
    name: string;
    modality: string;
    indications: string[];
    description: string;
    parameters?: string[];
    contraindications: string[];
  }> {
    return [
      {
        name: 'Brain CT without contrast',
        modality: 'CT',
        indications: ['trauma', 'headache', 'altered mental status'],
        description: 'Non-contrast CT examination of the brain',
        parameters: ['120 kVp', '200-400 mAs', '5mm slice thickness'],
        contraindications: ['pregnancy (relative)']
      },
      {
        name: 'Brain MRI T1/T2/FLAIR',
        modality: 'MR',
        indications: ['tumor', 'multiple sclerosis', 'seizure'],
        description: 'Multi-sequence MRI examination of the brain',
        parameters: ['T1-weighted', 'T2-weighted', 'FLAIR'],
        contraindications: ['metallic implants', 'pacemaker']
      },
      {
        name: 'Chest CT with contrast',
        modality: 'CT',
        indications: ['pulmonary embolism', 'lung cancer staging'],
        description: 'Contrast-enhanced CT examination of the chest',
        parameters: ['100-120 kVp', 'IV contrast', '1.25mm slice thickness'],
        contraindications: ['contrast allergy', 'renal impairment']
      }
    ];
  }
}