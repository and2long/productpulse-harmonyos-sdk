import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { preferences } from '@kit.ArkData';
import { CollectorClient } from './CollectorClient';
import { feedbackContent } from './FeedbackContent';

const ID_KEY = 'activeReporter.distinctID';
const LAST_REPORT_KEY = 'productpulse.lastActiveReport';

function shanghaiDay(time: number): number {
  return Math.floor((time + 8 * 3600000) / 86400000);
}

export class ProductPulse {
  private static initialization?: Promise<ProductPulse>;
  private static sourceKey?: string;
  private readonly store: preferences.Preferences;
  private readonly client: CollectorClient;
  readonly distinctId: string;
  private reportingAutomatically: boolean = false;

  private constructor(store: preferences.Preferences, sourceKey: string, id: string) {
    this.store = store;
    this.client = new CollectorClient(sourceKey);
    this.distinctId = id;
  }

  // Initialize on the first UIAbility foreground event in the main process.
  static async initialize(context: common.Context, sourceKey: string): Promise<ProductPulse> {
    if (ProductPulse.initialization) {
      if (ProductPulse.sourceKey !== sourceKey) {
        throw new Error('ProductPulse already uses another source key');
      }
      return ProductPulse.initialization;
    }
    ProductPulse.sourceKey = sourceKey;
    ProductPulse.initialization = ProductPulse.create(context.getApplicationContext(), sourceKey);
    try {
      return await ProductPulse.initialization;
    } catch (error) {
      ProductPulse.initialization = undefined;
      ProductPulse.sourceKey = undefined;
      throw error as Error;
    }
  }

  private static async create(context: common.ApplicationContext, sourceKey: string): Promise<ProductPulse> {
    try {
      const store = await preferences.getPreferences(context, { name: 'productpulse' });
      const stored = await store.get(ID_KEY, '');
      const id = typeof stored === 'string' && stored.length > 0 ? stored : util.generateRandomUUID();
      if (stored !== id) {
        await store.put(ID_KEY, id);
      }
      // Also retry persistence if an earlier initialization failed during flush.
      await store.flush();
      const pulse = new ProductPulse(store, sourceKey, id);
      context.on('applicationStateChange', {
        onApplicationForeground: () => { pulse.checkActive(); },
        onApplicationBackground: () => {}
      });
      pulse.checkActive();
      return pulse;
    } catch (error) {
      throw error as Error;
    }
  }

  async reportActive(): Promise<void> {
    const start = Date.now();
    await this.client.post('active', { 'distinct_id': this.distinctId });
    try {
      const last = this.store.getSync(LAST_REPORT_KEY, 0);
      // An older overlapping request can complete after a newer day's report.
      if (typeof last !== 'number' || last < start || last > Date.now()) {
        this.store.putSync(LAST_REPORT_KEY, start);
      }
      await this.store.flush();
    } catch (error) {
      throw error as Error;
    }
  }

  async submitFeedback(content: string, metadata: Record<string, string> = {}): Promise<void> {
    await this.client.post('feedback', { 'content': feedbackContent(content, metadata) });
  }

  private async checkActive(): Promise<void> {
    if (this.reportingAutomatically) {
      return;
    }
    this.reportingAutomatically = true;
    try {
      const last = this.store.getSync(LAST_REPORT_KEY, 0);
      if (typeof last !== 'number' || shanghaiDay(last) !== shanghaiDay(Date.now())) {
        await this.reportActive();
      }
    } catch {
      // Retry on the next foreground event without interrupting the host.
    } finally {
      this.reportingAutomatically = false;
    }
  }
}
