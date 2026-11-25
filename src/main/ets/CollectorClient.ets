import { http } from '@kit.NetworkKit';

export class ProductPulseError extends Error {
  readonly status: number;
  readonly code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

interface CollectorResponse {
  success?: boolean;
  code?: string;
  msg?: string;
}

export class CollectorClient {
  private readonly sourceKey: string;

  constructor(sourceKey: string) {
    this.sourceKey = sourceKey;
  }

  async post(endpoint: string, fields: Record<string, string>): Promise<void> {
    fields['source_key'] = this.sourceKey;
    const request = http.createHttp();
    try {
      const response = await request.request('https://productpulse.and2long.tech/api/' + endpoint, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json; charset=utf-8' },
        extraData: JSON.stringify(fields),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 15000
      });
      let body: CollectorResponse | null = null;
      try {
        body = JSON.parse(response.result as string) as CollectorResponse;
      } catch {
        // An empty or non-JSON error body still carries an HTTP status.
      }
      const status = response.responseCode;
      if (status < 200 || status >= 300) {
        const code = body?.code;
        const message = body?.msg;
        throw new ProductPulseError(status, typeof code === 'string' ? code : 'HTTP_ERROR',
          typeof message === 'string' ? message : 'Collector request failed');
      }
      if (body?.success !== true) {
        throw new ProductPulseError(status, 'INVALID_RESPONSE', 'Invalid collector response');
      }
    } catch (error) {
      throw error as Error;
    } finally {
      request.destroy();
    }
  }
}
