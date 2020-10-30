global class StripeGetChargesBatch implements Database.Batchable<StripeChargeItemParser>, Database.Stateful, Database.AllowsCallouts {

    public Integer pageSize;
    public String initAfterRecord;
    
    public Boolean hasMoreItems;
    
    global StripeGetChargesBatch(Integer pageSize){
        this(pageSize, null);
    }
    
    global StripeGetChargesBatch(Integer pageSize, String initAfterRecord){
        this.pageSize = pageSize;
        this.initAfterRecord = initAfterRecord;
        this.hasMoreItems = false;
    }
    
    global List<StripeChargeItemParser> start(Database.BatchableContext BC){
        String filterPage = 'limit=' + pageSize;
        if(this.initAfterRecord != null) filterPage = filterPage + '&starting_after=' + initAfterRecord;
        String jsonResponse = StripeConnection.getStripeEntity('charges', filterPage);
		jsonResponse = jsonResponse.replace('"currency":', '"currency_x":')
    								.replace('"Security Group":', '"Security_Group":')
    								.replace('"Donation Type":', '"Donation_Type":');
		StripeChargesParser parser = (StripeChargesParser)json.deserialize(jsonResponse, StripeChargesParser.class);
        this.hasMoreItems = parser.has_more;
        if(parser.data!=null){
            if(parser.data.size()>0) this.initAfterRecord = parser.data[parser.data.size()-1].id;
            return parser.data;
        }else{
            System.debug('parser.data is null');
        	return new List<StripeChargeItemParser>();
        }
    }
    
    global void execute(Database.BatchableContext BC, List<StripeChargeItemParser> scope){
        System.debug('Execute StripeGetChargesBatch');
        Map<String, Opportunity> opps = new Map<String, Opportunity>();
        Map<String, Account> accounts = new Map<String, Account>();
        Map<String, Contact> contactsInsert = new Map<String, Contact>();
        Map<String, String> emailContacts = new Map<String, String>();
        Opportunity auxOpp;
        
        String recordTypeOpp = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Donation') != null ? Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Donation').getRecordTypeId() : null;
        String recordTypeContact = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Donor') != null ? Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Donor').getRecordTypeId() : null;
        for(StripeChargeItemParser charge : scope){
            System.debug(charge.currency_x);
            auxOpp = new Opportunity();
            auxOpp.Stripe_ID__c = charge.id;
            auxOpp.RecordTypeId = recordTypeOpp;
            auxOpp.Name = 'Opp-' + charge.receipt_email + '-' + charge.amount;
            auxOpp.CloseDate = charge.getCloseDate();
            auxOpp.StageName = 'Closed Won';
            auxOpp.Amount = charge.amount;
            auxOpp.Receipt_Email__c = charge.receipt_email;
            emailContacts.put(charge.receipt_email, null);
            if(charge.metadata!=null){
                System.debug(charge.metadata.Security_Group);
                System.debug(charge.metadata.Donation_Type);
                auxOpp.Security_Group__c = charge.metadata.Security_Group;
                auxOpp.Campaign__c = charge.metadata.Campaign;
            }
            opps.put(charge.id, auxOpp);
        }
        
        for(Contact contact : [select Id, Email from Contact where Email in: emailContacts.keySet()]){
            emailContacts.put(contact.Email, contact.Id);
        }
        
        for(String key : emailContacts.keySet()){
            if(emailContacts.get(key)==null){
                contactsInsert.put(key, new Contact(LastName=key, Email=key, RecordTypeId=recordTypeContact));
            }
        }
        
        List<Database.SaveResult> saveResults;
        saveResults = Database.insert(contactsInsert.values(), false);
        for(Database.SaveResult saveResult : saveResults) {
            if(!saveResult.isSuccess()) {
            	for(Database.Error saveError : saveResult.getErrors()) 
                	System.debug('StripeGetChargesBatch - Contact Insert Error: ' + saveError.getMessage());
        	}
        }
        
        for(Contact contact : contactsInsert.values()){
            if(contact.Id!=null){
                emailContacts.put(contact.Email, contact.Id);
            }
        }
        
        for(Opportunity o : opps.values()){
        	if(o.Receipt_Email__c!=null)
            {
             	if(emailContacts.get(o.Receipt_Email__c)!=null) 
                	o.npsp__Primary_Contact__c = emailContacts.get(o.Receipt_Email__c);
                    //System.debug('Add: ' + acc.Name + '-' + acc.Id);
            }
      	}
        
        List<Database.UpsertResult> upsertResults;
        upsertResults = Database.upsert(opps.values(), Opportunity.Stripe_ID__c, false);
        for(Database.UpsertResult upsertResult:upsertResults) {
            if(!upsertResult.isSuccess()) {
            	for(Database.Error upsertError : upsertResult.getErrors()) 
                	System.debug('StripeGetChargesBatch - Opportunity Upsert Error: ' + upsertError.getMessage());
        	}
        }
    }
    
    global void finish(Database.BatchableContext BC){
        System.debug('Finish StripeGetChargesBatch: initPage->' + initAfterRecord);
        if(!Test.isRunningTest()){
            if(this.hasMoreItems) System.scheduleBatch(new StripeGetChargesBatch(pageSize, initAfterRecord), 'StripeGetChargesBatch-' + initAfterRecord, 1, 100);
            //else Database.executeBatch(new ShopifyCheckoutBatch(instance, isAll, pageSize));
        }
    }
    
}