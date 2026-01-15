public without sharing class PlanCreationService {
    public class PlanInput {
        @InvocableVariable(required=true)
        public Id planTemplateId;

        @InvocableVariable
        public Id recordId;

        @InvocableVariable
        public Date startDate;

        @InvocableVariable
        public String lookupFieldApiName;
    }
 
    @InvocableMethod (label='Create Plan and Plan Items')
    public static void createPlan(List<PlanInput> inputs){
        PlanInput input = inputs[0];
        Plan_Template__c planTemplate = [SELECT Id, Name, Description__c, Default_Owner_Type__c, Owner_API_Name__c, Owner_Queue__c, Owner_User__c, OwnerId,
                                        (SELECT Id, Name, Plan_Template_If_Completed__c, Step_Order__c, Is_Mandatory__c, Instructions__c, Duration_Days__c, Previous_Plan_Template_Item__c, Default_Owner_Type__c, Owner_API_Name__c, Owner_Queue__c, Owner_User__c FROM Plan_Template_Items__r order by Step_Order__c) FROM Plan_Template__c WHERE Id = :input.planTemplateId LIMIT 1];
        
		List<Plan_Template_Item__c> templateItems = planTemplate.Plan_Template_Items__r;
		 
		String sObjName = input.recordId.getSObjectType().getDescribe().getName();
		
		Set<String> ownerPaths = new Set<String>();

		if (planTemplate.Owner_API_Name__c != null) ownerPaths.add(planTemplate.Owner_API_Name__c);

		for (Plan_Template_Item__c pti : templateItems) {
			if (pti.Owner_API_Name__c != null) ownerPaths.add(pti.Owner_API_Name__c);
		}

		String query = 'SELECT Id';
		for (String p : ownerPaths) {
			query += ',' + p;
		}
		query += ' FROM ' + sObjName + ' WHERE Id = \'' + String.valueOf(input.recordId) + '\'';

		SObject record = Database.query(query);

		Id planAssignedTo = getOwner(planTemplate.Default_Owner_Type__c, record, planTemplate, planTemplate);



		Plan__c plan = new Plan__c (Name = planTemplate.Name,
									Plan_Template__c = planTemplate.Id,
									Start_Date__c = Date.today(),
									Notes__c = planTemplate.Description__c);
        plan.put(input.lookupFieldApiName, input.recordId);
		plan.OwnerId = planAssignedTo;
		
		insert plan;
		List<Plan_Item__c> planItems = new List<Plan_Item__c>();
		Map<Id,Plan_Item__c> planTemplateItemToPlanItem = new Map<Id,Plan_Item__c>();
		Map<Id, Plan_Template_Item__c> templateItemById = new Map<Id, Plan_Template_Item__c>(templateItems);
		
		for (Plan_Template_Item__c pti : templateItems){
			Plan_Item__c planItem = new Plan_Item__c (Plan__c = plan.Id,
													Plan_Template_If_Completed__c = pti.Plan_Template_If_Completed__c,
													Step_Order__c = pti.Step_Order__c,
													Is_Mandatory__c = pti.Is_Mandatory__c,
													Instructions__c = pti.Instructions__c);		
			planItems.add(planItem);
			planTemplateItemToPlanItem.put(pti.Id, planItem);
		}
		
		insert planItems;

		List<Plan_Item__c> planItemPreviousUpdate = new List<Plan_Item__c>();
		for (Plan_Template_Item__c pti : templateItems) {
			if (pti.Previous_Plan_Template_Item__c == null) continue;

			Plan_Item__c current = planTemplateItemToPlanItem.get(pti.Id);
			Plan_Item__c prev = planTemplateItemToPlanItem.get(pti.Previous_Plan_Template_Item__c);

			if (prev != null) {
				current.Previous_Plan_Item__c = prev.Id;
				planItemPreviousUpdate.add(current);
			}
		}
		if (planItemPreviousUpdate.size() > 0) {
			update planItemPreviousUpdate;
		}

		List<Task> tasks = new List<Task>();
		
		for (Plan_Template_Item__c pti : templateItems){
			Plan_Item__c pi = planTemplateItemToPlanItem.get(pti.Id);

			Id TaskAssignedTo = getOwner(pti.Default_Owner_Type__c, record, pti, planTemplate);
			system.debug('TaskAssignedTo: ' + TaskAssignedTo + 'pti: ' + pti.Name);

			Date baseDate = (input.startDate != null) ? input.startDate : Date.today();
            Integer durationDays = pti.Duration_Days__c != null ? Integer.valueOf(pti.Duration_Days__c) : 0;

			Task t = new Task (Subject = pti.Name,
								plan_Item__c = pi.Id,
								WhatId = input.recordId,
								Status = pi.Previous_Plan_Item__c != null ? 'Waiting in Dependency' : 'Open',
								ActivityDate = baseDate.addDays(durationDays),
								OwnerId = TaskAssignedTo);
			tasks.add(t);
		}
		
		insert tasks;
    }

	public class PlanCreationException extends Exception {}

	private static Id getOwner(String type, SObject record, SObject template, Plan_Template__c parentTemplate){
		Id fallback = (Id)parentTemplate.get('OwnerId');

		Object raw = (type == 'User') ? template.get('Owner_User__c')
				: (type == 'Queue') ? template.get('Owner_Queue__c')
				: null;
		Id ownerId = resolveOwnerId(raw);

		if (ownerId == null) {
			String ownerPath = (String)template.get('Owner_API_Name__c');
			ownerId = resolveOwnerId(getByPath(record, ownerPath));
		}

		if (ownerId == null) return fallback;

		if (!ownerExists(ownerId)) return fallback;

		if (type == 'User' && String.valueOf(ownerId).startsWith('005')) {
			User u = [SELECT IsActive FROM User WHERE Id = :ownerId LIMIT 1];
			if (!u.IsActive) return fallback;
		}

		Boolean userOrQueue = String.valueOf(ownerId).startsWith('005') || String.valueOf(ownerId).startsWith('00G');
		return userOrQueue ? ownerId : fallback;
	}

	private static Id resolveOwnerId(Object val) {
		if (val == null) return null;

		if (val instanceof Id) return (Id)val;

		if (val instanceof String) {
			String s = ((String)val).trim();
			if (String.isBlank(s)) return null;

			if (s.startsWith('005') || s.startsWith('00G')) {
				try { return (Id)s; } catch (Exception e) { return null; }
			}
		}

		return null;
	}

	private static Boolean ownerExists(Id ownerId) {
		if (ownerId == null) return false;

		String s = String.valueOf(ownerId);

		if (s.startsWith('005')) {
			return [SELECT COUNT() FROM User WHERE Id = :ownerId] > 0;
		}
		if (s.startsWith('00G')) {
			return [SELECT COUNT() FROM Group WHERE Id = :ownerId] > 0;
		}
		return false;
	}


	private static Object getByPath(SObject root, String path) {
		if (root == null || String.isBlank(path)) return null;

		try {
			List<String> parts = path.split('\\.');
			SObject current = root;

			for (Integer i = 0; i < parts.size() - 1; i++) {
				current = current.getSObject(parts[i]);
				if (current == null) return null;
			}

			return current.get(parts[parts.size() - 1]);
		} catch (Exception e) {
			return null;
		}
	}


}