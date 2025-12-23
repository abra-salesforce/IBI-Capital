public with sharing class ActionPlanPanelController {
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

        String soql =
            'SELECT Id, Name, Status__c, Completed_Plan_Item__c, Total_Plan_Item__c, Owner.Name, Start_Date__c, Progress_Formula__c ' +
            'FROM Plan__c WHERE ' + apiFieldName + ' = :recordId ORDER BY CreatedDate ASC';

        return Database.query(soql);
    }
    @AuraEnabled
    public static void updateTaskStatus(Id taskId, String status) {
        Task task = new Task (Id = taskId, Status = status);
        update task;
    }
}