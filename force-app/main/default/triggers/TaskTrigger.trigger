trigger TaskTrigger on Task (after insert, after update) {
    if(Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)){
        TaskHandler.updatePlanItemStatus(Trigger.oldMap, Trigger.new);
    }
}