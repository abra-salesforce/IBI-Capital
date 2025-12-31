trigger PlanItemTrigger on Plan_Item__c (after delete) {
    if(Trigger.isAfter) {
        if(Trigger.isDelete) {
            PlanItemTriggerHandler.handleAfterDelete(Trigger.old);
        }
    }
}