/**
 * Comprehensive Error Handling Utilities
 * Provides standardized error handling for the DICOM MCP server
 */

export enum ErrorCode {
  // File System Errors
  FILE_NOT_FOUND = 'FILE_NOT_FOUND',
  FILE_ACCESS_DENIED = 'FILE_ACCESS_DENIED',
  FILE_TOO_LARGE = 'FILE_TOO_LARGE',
  FILE_CORRUPTED = 'FILE_CORRUPTED',
  
  // DICOM Parsing Errors
  INVALID_DICOM_FORMAT = 'INVALID_DICOM_FORMAT',
  DICOM_PARSE_ERROR = 'DICOM_PARSE_ERROR',
  MISSING_REQUIRED_TAGS = 'MISSING_REQUIRED_TAGS',
  INVALID_PIXEL_DATA = 'INVALID_PIXEL_DATA',
  UNSUPPORTED_TRANSFER_SYNTAX = 'UNSUPPORTED_TRANSFER_SYNTAX',
  
  // Validation Errors
  COMPLIANCE_CHECK_FAILED = 'COMPLIANCE_CHECK_FAILED',
  TERMINOLOGY_VALIDATION_FAILED = 'TERMINOLOGY_VALIDATION_FAILED',
  INVALID_PARAMETERS = 'INVALID_PARAMETERS',
  
  // Processing Errors
  PIXEL_ANALYSIS_FAILED = 'PIXEL_ANALYSIS_FAILED',
  MEMORY_ALLOCATION_ERROR = 'MEMORY_ALLOCATION_ERROR',
  PROCESSING_TIMEOUT = 'PROCESSING_TIMEOUT',
  
  // System Errors
  UNKNOWN_ERROR = 'UNKNOWN_ERROR',
  INTERNAL_SERVER_ERROR = 'INTERNAL_SERVER_ERROR'
}

export interface DICOMError {
  code: ErrorCode;
  message: string;
  details?: any;
  timestamp: Date;
  context?: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  recoverable: boolean;
  suggestions?: string[];
}

export class DICOMErrorHandler {
  private static instance: DICOMErrorHandler;
  private errorLog: DICOMError[] = [];
  private maxLogSize = 1000;

  private constructor() {}

  static getInstance(): DICOMErrorHandler {
    if (!DICOMErrorHandler.instance) {
      DICOMErrorHandler.instance = new DICOMErrorHandler();
    }
    return DICOMErrorHandler.instance;
  }

  /**
   * Create a standardized DICOM error
   */
  createError(
    code: ErrorCode,
    message: string,
    context?: string,
    details?: any,
    suggestions?: string[]
  ): DICOMError {
    const error: DICOMError = {
      code,
      message,
      details,
      timestamp: new Date(),
      context,
      severity: this.determineSeverity(code),
      recoverable: this.isRecoverable(code),
      suggestions: suggestions || this.getDefaultSuggestions(code)
    };

    this.logError(error);
    return error;
  }

  /**
   * Handle and format errors for MCP responses
   */
  handleError(error: unknown, context?: string): {
    success: false;
    error: DICOMError;
    response: {
      content: Array<{
        type: 'text';
        text: string;
      }>;
    };
  } {
    let dicomError: DICOMError;

    if (error instanceof Error) {
      // Determine error code based on error message or type
      const code = this.categorizeError(error);
      dicomError = this.createError(
        code,
        error.message,
        context,
        {
          stack: error.stack,
          name: error.name
        }
      );
    } else if (typeof error === 'string') {
      dicomError = this.createError(
        ErrorCode.UNKNOWN_ERROR,
        error,
        context
      );
    } else {
      dicomError = this.createError(
        ErrorCode.UNKNOWN_ERROR,
        'An unknown error occurred',
        context,
        error
      );
    }

    return {
      success: false,
      error: dicomError,
      response: {
        content: [
          {
            type: 'text' as const,
            text: JSON.stringify({
              success: false,
              error: {
                code: dicomError.code,
                message: dicomError.message,
                severity: dicomError.severity,
                recoverable: dicomError.recoverable,
                context: dicomError.context,
                suggestions: dicomError.suggestions,
                timestamp: dicomError.timestamp.toISOString()
              }
            }, null, 2)
          }
        ]
      }
    };
  }

  /**
   * Validate file path and accessibility
   */
  async validateFilePath(filePath: string): Promise<void> {
    if (!filePath || typeof filePath !== 'string') {
      throw this.createError(
        ErrorCode.INVALID_PARAMETERS,
        'File path is required and must be a string',
        'validateFilePath',
        { filePath }
      );
    }

    if (!filePath.startsWith('/')) {
      throw this.createError(
        ErrorCode.INVALID_PARAMETERS,
        'File path must be absolute',
        'validateFilePath',
        { filePath },
        ['Use absolute file paths starting with "/"']
      );
    }

    try {
      const fs = await import('fs');
      
      // Check if file exists
      if (!fs.existsSync(filePath)) {
        throw this.createError(
          ErrorCode.FILE_NOT_FOUND,
          `File not found: ${filePath}`,
          'validateFilePath',
          { filePath },
          [
            'Verify the file path is correct',
            'Check if the file has been moved or deleted',
            'Ensure proper file permissions'
          ]
        );
      }

      // Check file accessibility
      try {
        fs.accessSync(filePath, fs.constants.R_OK);
      } catch {
        throw this.createError(
          ErrorCode.FILE_ACCESS_DENIED,
          `Cannot read file: ${filePath}`,
          'validateFilePath',
          { filePath },
          [
            'Check file permissions',
            'Ensure the process has read access to the file',
            'Verify the file is not locked by another process'
          ]
        );
      }

      // Check file size (warn if very large)
      const stats = fs.statSync(filePath);
      const maxSize = 2 * 1024 * 1024 * 1024; // 2GB
      
      if (stats.size > maxSize) {
        console.warn(`Warning: Large file detected (${stats.size} bytes): ${filePath}`);
      }

    } catch (error) {
      if (error instanceof Error && 'code' in error) {
        throw error; // Re-throw our custom errors
      }
      throw this.createError(
        ErrorCode.FILE_ACCESS_DENIED,
        `Cannot access file: ${filePath}`,
        'validateFilePath',
        { originalError: error }
      );
    }
  }

  /**
   * Validate array of file paths
   */
  async validateFilePaths(filePaths: string[]): Promise<void> {
    if (!Array.isArray(filePaths)) {
      throw this.createError(
        ErrorCode.INVALID_PARAMETERS,
        'File paths must be provided as an array',
        'validateFilePaths',
        { filePaths }
      );
    }

    if (filePaths.length === 0) {
      throw this.createError(
        ErrorCode.INVALID_PARAMETERS,
        'At least one file path must be provided',
        'validateFilePaths',
        { filePaths }
      );
    }

    if (filePaths.length > 100) {
      throw this.createError(
        ErrorCode.INVALID_PARAMETERS,
        'Too many files requested (maximum 100)',
        'validateFilePaths',
        { count: filePaths.length },
        ['Process files in smaller batches', 'Use directory scanning instead']
      );
    }

    // Validate each file path
    for (let i = 0; i < filePaths.length; i++) {
      try {
        await this.validateFilePath(filePaths[i]);
      } catch (error) {
        if (error instanceof Error && 'code' in error) {
          // Add index information to the error
          const dicomError = error as any;
          dicomError.context = `validateFilePaths[${i}]`;
          dicomError.details = { ...dicomError.details, index: i, filePath: filePaths[i] };
          throw error;
        }
        throw error;
      }
    }
  }

  /**
   * Wrap async operations with error handling
   */
  async wrapAsync<T>(
    operation: () => Promise<T>,
    context: string,
    timeout: number = 30000
  ): Promise<T> {
    return new Promise(async (resolve, reject) => {
      // Set up timeout
      const timeoutId = setTimeout(() => {
        reject(this.createError(
          ErrorCode.PROCESSING_TIMEOUT,
          `Operation timed out after ${timeout}ms`,
          context,
          { timeout },
          ['Increase timeout value', 'Use smaller files', 'Process in batches']
        ));
      }, timeout);

      try {
        const result = await operation();
        clearTimeout(timeoutId);
        resolve(result);
      } catch (error) {
        clearTimeout(timeoutId);
        
        if (error instanceof Error && 'code' in error) {
          reject(error); // Already a DICOM error
        } else {
          reject(this.createError(
            this.categorizeError(error as Error),
            `Operation failed: ${error}`,
            context,
            { originalError: error }
          ));
        }
      }
    });
  }

  /**
   * Get error statistics
   */
  getErrorStatistics(): {
    totalErrors: number;
    errorsByCode: { [key: string]: number };
    errorsBySeverity: { [key: string]: number };
    recentErrors: DICOMError[];
  } {
    const errorsByCode: { [key: string]: number } = {};
    const errorsBySeverity: { [key: string]: number } = {};

    for (const error of this.errorLog) {
      errorsByCode[error.code] = (errorsByCode[error.code] || 0) + 1;
      errorsBySeverity[error.severity] = (errorsBySeverity[error.severity] || 0) + 1;
    }

    return {
      totalErrors: this.errorLog.length,
      errorsByCode,
      errorsBySeverity,
      recentErrors: this.errorLog.slice(-10) // Last 10 errors
    };
  }

  /**
   * Clear error log
   */
  clearErrorLog(): void {
    this.errorLog = [];
  }

  private logError(error: DICOMError): void {
    this.errorLog.push(error);
    
    // Trim log if it exceeds maximum size
    if (this.errorLog.length > this.maxLogSize) {
      this.errorLog = this.errorLog.slice(-this.maxLogSize);
    }

    // Log to console based on severity
    switch (error.severity) {
      case 'critical':
        console.error('[CRITICAL DICOM ERROR]:', error);
        break;
      case 'high':
        console.error('[DICOM ERROR]:', error.message);
        break;
      case 'medium':
        console.warn('[DICOM WARNING]:', error.message);
        break;
      case 'low':
        console.info('[DICOM INFO]:', error.message);
        break;
    }
  }

  private categorizeError(error: Error): ErrorCode {
    const message = error.message.toLowerCase();

    // File system errors
    if (message.includes('enoent') || message.includes('not found')) {
      return ErrorCode.FILE_NOT_FOUND;
    }
    if (message.includes('eacces') || message.includes('permission')) {
      return ErrorCode.FILE_ACCESS_DENIED;
    }
    if (message.includes('emfile') || message.includes('too many')) {
      return ErrorCode.FILE_TOO_LARGE;
    }

    // DICOM errors
    if (message.includes('dicom') && message.includes('parse')) {
      return ErrorCode.DICOM_PARSE_ERROR;
    }
    if (message.includes('invalid') && message.includes('dicom')) {
      return ErrorCode.INVALID_DICOM_FORMAT;
    }
    if (message.includes('pixel') && message.includes('data')) {
      return ErrorCode.INVALID_PIXEL_DATA;
    }
    if (message.includes('transfer syntax')) {
      return ErrorCode.UNSUPPORTED_TRANSFER_SYNTAX;
    }

    // Memory errors
    if (message.includes('out of memory') || message.includes('allocation')) {
      return ErrorCode.MEMORY_ALLOCATION_ERROR;
    }

    return ErrorCode.UNKNOWN_ERROR;
  }

  private determineSeverity(code: ErrorCode): 'low' | 'medium' | 'high' | 'critical' {
    switch (code) {
      case ErrorCode.INTERNAL_SERVER_ERROR:
      case ErrorCode.MEMORY_ALLOCATION_ERROR:
        return 'critical';
        
      case ErrorCode.FILE_NOT_FOUND:
      case ErrorCode.FILE_ACCESS_DENIED:
      case ErrorCode.INVALID_DICOM_FORMAT:
      case ErrorCode.DICOM_PARSE_ERROR:
        return 'high';
        
      case ErrorCode.INVALID_PARAMETERS:
      case ErrorCode.COMPLIANCE_CHECK_FAILED:
      case ErrorCode.PROCESSING_TIMEOUT:
        return 'medium';
        
      case ErrorCode.FILE_TOO_LARGE:
      case ErrorCode.TERMINOLOGY_VALIDATION_FAILED:
        return 'low';
        
      default:
        return 'medium';
    }
  }

  private isRecoverable(code: ErrorCode): boolean {
    switch (code) {
      case ErrorCode.INTERNAL_SERVER_ERROR:
      case ErrorCode.MEMORY_ALLOCATION_ERROR:
      case ErrorCode.FILE_CORRUPTED:
        return false;
        
      case ErrorCode.FILE_NOT_FOUND:
      case ErrorCode.FILE_ACCESS_DENIED:
      case ErrorCode.INVALID_PARAMETERS:
      case ErrorCode.PROCESSING_TIMEOUT:
        return true;
        
      default:
        return true;
    }
  }

  private getDefaultSuggestions(code: ErrorCode): string[] {
    switch (code) {
      case ErrorCode.FILE_NOT_FOUND:
        return [
          'Verify the file path is correct',
          'Check if the file exists',
          'Ensure proper file permissions'
        ];
        
      case ErrorCode.INVALID_DICOM_FORMAT:
        return [
          'Verify the file is a valid DICOM file',
          'Check the file header for DICM signature',
          'Try with a different DICOM file'
        ];
        
      case ErrorCode.MEMORY_ALLOCATION_ERROR:
        return [
          'Close other applications to free memory',
          'Process smaller files',
          'Use batch processing for large datasets'
        ];
        
      case ErrorCode.PROCESSING_TIMEOUT:
        return [
          'Use smaller files',
          'Increase the timeout value',
          'Process files in batches'
        ];
        
      case ErrorCode.INVALID_PARAMETERS:
        return [
          'Check the parameter format',
          'Refer to the API documentation',
          'Validate input values'
        ];
        
      default:
        return [
          'Check the error details for more information',
          'Verify input parameters',
          'Try the operation again'
        ];
    }
  }
}

/**
 * Global error handler utility
 */
export const errorHandler = DICOMErrorHandler.getInstance();