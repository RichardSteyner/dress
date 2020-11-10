global class StripeGetSchedule implements Schedulable {
    
    String instance;
    Integer pageSize;

    public StripeGetSchedule(String instance, Integer pageSize){
        this.instance = instance;
        this.pageSize = pageSize;
    }
    
    global void execute(SchedulableContext ctx) {
        Database.executeBatch(new StripeGetChargesBatch(instance, pageSize), 100);
    }

}
