trigger PlanTrigger on Plan__c (before delete) {
    if(Trigger.isBefore) {
        if(Trigger.isDelete) {
            PlanTriggerHandler.handleBeforeDelete(Trigger.old);
        }
    }

}