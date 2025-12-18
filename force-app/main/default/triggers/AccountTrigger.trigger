trigger AccountTrigger on Account (before insert, before update) {
    if(Trigger.isBefore) {
        if(Trigger.isInsert) {
            AccountTriggerHandler.handleBeforeInsert(Trigger.new);
        }
        if(Trigger.isUpdate) {
            AccountTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}