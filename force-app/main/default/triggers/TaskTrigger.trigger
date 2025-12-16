trigger TaskTrigger on Task (after insert, after update) {
    if(Trigger.isAfter) {
        if(Trigger.isInsert) {
            TaskTriggerHandler.handleAfterInsert(Trigger.new);
        }
        if(Trigger.isUpdate) {
            TaskTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}