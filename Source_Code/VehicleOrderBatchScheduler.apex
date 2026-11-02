/**
 * @description Schedulable class to trigger VehicleOrderBatch on a recurring schedule.
 *              Default schedule: Daily at 12:00 PM.
 * @group WhatsNext CRM
 */
public with sharing class VehicleOrderBatchScheduler implements Schedulable {

    public static final String DEFAULT_CRON_DAILY_NOON = '0 0 12 * * ?';
    public static final Integer DEFAULT_BATCH_SIZE = 50;

    public void execute(SchedulableContext sc) {
        VehicleOrderBatch batchJob = new VehicleOrderBatch();
        Database.executeBatch(batchJob, DEFAULT_BATCH_SIZE);
    }

    public static String scheduleDailyAtNoon() {
        return System.schedule(
            'WhatsNext Vehicle Order Confirmation Job',
            DEFAULT_CRON_DAILY_NOON,
            new VehicleOrderBatchScheduler()
        );
    }
}
