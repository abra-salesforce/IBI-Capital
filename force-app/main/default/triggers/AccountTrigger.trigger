trigger AccountTrigger on Account (before insert, before update, after insert, after update, after delete, after undelete) {
    if(Trigger.isBefore) {
        if(Trigger.isInsert) {
            AccountTriggerHandler.handleBeforeInsert(Trigger.new);
        }
        if(Trigger.isUpdate) {
            AccountTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
    if(Trigger.isAfter) {
        if(Trigger.isInsert) {
            AccountTriggerHandler.handleAfterInsert(Trigger.new);
        }
        if(Trigger.isUpdate) {
            AccountTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
        if(Trigger.isDelete) {
            AccountTriggerHandler.handleAfterDelete(Trigger.old);
        }
        if(Trigger.isUndelete) {
            AccountTriggerHandler.handleAfterUndelete(Trigger.new);
        }
    }
}