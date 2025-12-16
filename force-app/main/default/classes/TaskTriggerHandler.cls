public with sharing class TaskTriggerHandler {
    public static void handleAfterInsert(List <Task> tasks){
        TaskPlanItemService.linkTaskToPlanItem(tasks);
        TaskPlanItemService.syncPlanItemStatus(tasks, null);
    }
    public static void handleAfterUpdate(List <Task> tasks, Map <Id,Task> oldTasks){
        TaskPlanItemService.syncPlanItemStatus(tasks, oldTasks);
        TaskPlanItemService.reopenTaskProcessing(tasks, oldTasks);
    }
}