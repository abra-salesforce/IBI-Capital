public with sharing class ActionPlanPanelController {

    private static final String PLAN_FIELDS =
        'Id, Name, Status__c, Completed_Plan_Item__c, Total_Plan_Item__c,' +
        ' Total_Mandatory_Plan_Item__c, Completed_Mandatory_Plan_Item__c,' +
        ' Progress_Mandatory_Plan_FormulaItem__c, Owner.Name, Start_Date__c,' +
        ' Progress_Formula__c';

    @AuraEnabled
    public static List<Plan__c> getPlans(Id recordId, String apiFieldName){
        if (recordId == null || String.isBlank(apiFieldName)) return new List<Plan__c>();

        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Plan__c.fields.getMap();
        if (!fields.containsKey(apiFieldName)) {
            throw new AuraHandledException('Invalid Plan__c field: ' + apiFieldName);
        }

        Schema.DescribeFieldResult d = fields.get(apiFieldName).getDescribe();
        if (d.getType() != Schema.DisplayType.REFERENCE) {
            throw new AuraHandledException('Field is not a lookup: ' + apiFieldName);
        }

        String query =
            'SELECT ' + PLAN_FIELDS +
            ' FROM Plan__c WHERE ' + apiFieldName + ' = :recordId ' +
            ' ORDER BY CreatedDate ASC';

        return Database.query(query);
    }

    @AuraEnabled
    public static List<Task> getPlanTasks(Id planId) {
        List<Plan_Item__c> items = [
        SELECT Task_ID__c
        FROM Plan_Item__c
        WHERE Plan__c = :planId
        ];

        Set<Id> taskIds = new Set<Id>();
        for (Plan_Item__c pi : items) {
        if (pi.Task_ID__c != null) taskIds.add((Id)pi.Task_ID__c);
        }
        if (taskIds.isEmpty()) return new List<Task>();

        return [
        SELECT Id, Subject, Status, Description, ActivityDate, OwnerId, Owner.Name, Plan_Item__r.Instructions__c
        FROM Task
        WHERE Id IN :taskIds order by Plan_Item__r.Step_Order__c
        ];
    }

    @AuraEnabled
    public static void updateTaskStatus(Id taskId, String status) {
        Task task = new Task (Id = taskId, Status = status);
        update task;
    }

    @AuraEnabled(cacheable=false)
    public static Plan__c getPlanById(Id planId) {
        String soql =
            'SELECT ' + PLAN_FIELDS +
            ' FROM Plan__c WHERE Id = :planId LIMIT 1';

        List<Plan__c> res = Database.query(soql);
        return res.isEmpty() ? null : res[0];
    }

    @AuraEnabled
    public static void updateTaskDescription(Id taskId, String description){
        Task task = new Task (Id = taskId, Description = description);
        try {
            update task;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // change owner modal

    public class OwnerOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String iconName;
    }

    @AuraEnabled(cacheable=true)
    public static List<OwnerOption> searchOwners(String ownerType, String searchTerm) {
        List<OwnerOption> results = new List<OwnerOption>();
        Boolean hasSearch = !String.isBlank(searchTerm);
        String likeTerm = hasSearch ? ('%' + searchTerm + '%') : '%';

        Integer limitSize = hasSearch ? 20 : 3;

        if (ownerType == 'User') {
            for (User u : [SELECT Id, Name FROM User WHERE IsActive = true AND Name LIKE :likeTerm ORDER BY Name LIMIT :limitSize]) {
                OwnerOption opt = new OwnerOption();
                opt.id = u.Id;
                opt.name = u.Name;
                opt.iconName = 'standard:user';
                results.add(opt);
            }
        } else if (ownerType == 'Queue') {
            for (Group g : [SELECT Id, Name FROM Group WHERE Type = 'Queue' AND Id IN (SELECT QueueId FROM QueueSobject WHERE SObjectType = 'Task')
                            AND Name LIKE :likeTerm ORDER BY Name LIMIT :limitSize]) {
                OwnerOption opt = new OwnerOption();
                opt.id = g.Id;
                opt.name = g.Name;
                opt.iconName = 'standard:queue';
                results.add(opt);
            }
        }

        return results;
    }

    @AuraEnabled
    public static void changeTaskOwner(Id taskId, Id ownerId) {
        Task t = [SELECT Id, OwnerId FROM Task WHERE Id = :taskId LIMIT 1];
        t.OwnerId = ownerId;
        update t;
    }

}