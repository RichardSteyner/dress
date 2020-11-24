global class StripeGetChargesBatch implements Database.Batchable<StripeChargeItemParser>, Database.Stateful, Database.AllowsCallouts {

    public String instance;
    public Integer pageSize;
    public String initAfterRecord;
    
    public Boolean hasMoreItems;
    
    global StripeGetChargesBatch(String instance, Integer pageSize){
        this(instance, pageSize, null);
    }
    
    global StripeGetChargesBatch(String instance, Integer pageSize, String initAfterRecord){
        this.instance = instance;
        this.pageSize = pageSize;
        this.initAfterRecord = initAfterRecord;
        this.hasMoreItems = false;
    }
    
    global List<StripeChargeItemParser> start(Database.BatchableContext BC){
        String filterPage = 'limit=' + pageSize;
        if(this.initAfterRecord != null) filterPage = filterPage + '&starting_after=' + initAfterRecord;
        String jsonResponse = StripeConnection.getStripeEntity(instance, 'charges', filterPage);
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
        System.debug('Execute StripeGetChargesBatch-' + instance);
        Map<String, Opportunity> opps = new Map<String, Opportunity>();
        Map<String, Account> accountsInsert = new Map<String, Account>();
        Map<String, Contact> contactsInsert = new Map<String, Contact>();
        Map<String, Contact> contactsUpdate = new Map<String, Contact>();
        Map<String, String> emailContacts = new Map<String, String>();
        Map<String, String> emailAccounts = new Map<String, String>();
        Map<String, Contact> mapContacts = new Map<String, Contact>();
        Map<String, String> affiliations = new Map<String, String>();
        Map<String, Account> affiliationsInsert = new Map<String, Account>();
        Opportunity auxOpp;
        Contact auxContact;
        String auxReceiptEmail = '', auxFirstName='', auxLastName='';
        
        String recordTypeOpp = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Donation') != null ? Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Donation').getRecordTypeId() : null;
        String recordTypeContact = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Donor') != null ? Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Donor').getRecordTypeId() : null;
        for(StripeChargeItemParser charge : scope){
            if(charge.status!=null && charge.status.equalsIgnoreCase('succeeded')){
                System.debug(charge.currency_x);
                auxOpp = new Opportunity();
                auxOpp.Stripe_ID__c = charge.id;
                auxOpp.RecordTypeId = recordTypeOpp;
                auxOpp.CloseDate = charge.getCloseDate();
                auxOpp.StageName = 'Closed Won';
                auxOpp.Amount = charge.amount!=null ? charge.amount/100 : 0;
                auxReceiptEmail = charge.getEmail();

                if(String.IsBlank(auxReceiptEmail) && String.IsNotBlank(charge.customer)){
                    String jsonResponseCustomer = StripeConnection.getStripeEntity(instance, 'customers/' + charge.customer, '');
                    StripeCustomerParser customerParser = (StripeCustomerParser)json.deserialize(jsonResponseCustomer, StripeCustomerParser.class);
                    auxReceiptEmail = customerParser.getEmail();
                    auxFirstName = customerParser.getFirstName();
                    auxLastName = customerParser.getLastName()!=null ? customerParser.getLastName() : customerParser.getNameFromEmail();
                }else{
                    auxFirstName = '';
                    auxLastName = 'Name null';
                }

                auxOpp.Name = 'Opp-' + auxReceiptEmail + '-' + (charge.amount!=null ? charge.amount/100 : 0);
                auxOpp.Receipt_Email__c = auxReceiptEmail;
                auxOpp.Description = charge.description;
                if(String.IsNotBlank(auxReceiptEmail)) emailContacts.put(auxReceiptEmail, null);
                if(String.IsNotBlank(auxReceiptEmail)) emailAccounts.put(auxReceiptEmail, null);
                auxContact = new Contact(FirstName=(String.IsNotBlank(charge.getFirstName()) ? charge.getFirstName() : auxFirstName),
                                                            LastName=(String.IsNotBlank(charge.getLastName()) ? charge.getLastName() : charge.getName()!='Name null' ? charge.getName() : auxLastName),
                                                            MailingStreet=charge.getStreet(), MailingCity=charge.getCity(), MailingState=charge.getState(), 
                                                            MailingPostalCode=charge.getPostalCode(), MailingCountry=charge.getCountry(), 
                                                            OtherStreet=charge.getStreet(), OtherCity=charge.getCity(), OtherState=charge.getState(), 
                                                            OtherPostalCode=charge.getPostalCode(), OtherCountry=charge.getCountry());
                if(charge.metadata!=null){
                    System.debug(charge.metadata.Security_Group);
                    //System.debug(charge.metadata.Donation_Type);
                    auxOpp.Security_Group__c = charge.metadata.Security_Group;
                    auxOpp.Campaign__c = charge.metadata.Campaign;
                    auxOpp.Donation_Notes__c = charge.metadata.Notes;
                    if(String.IsNotBlank(charge.metadata.Company)) { 
                        auxContact.Stripe_Primary_Affiliation__c = charge.metadata.Company.tolowercase();
                        affiliations.put(charge.metadata.Company.tolowercase(), null);
                    }
                }
                if(String.IsBlank(auxOpp.Security_Group__c)) auxOpp.Security_Group__c = instance.containsIgnoreCase('Francisco') ? 'San Francisco' : 'San Jose';
                if(String.IsNotBlank(auxReceiptEmail)) mapContacts.put(auxReceiptEmail, auxContact);
                opps.put(charge.id, auxOpp);
            }else
                System.debug('Charge with status=' + charge.status);
        }

        //Buscar affiliations existentes
        for(Account acc : [select ID, Name from Account where name in: affiliations.keySet()]){
            affiliations.put(acc.Name.tolowercase(), acc.ID);
        }

        //Agregar affiliations para insertar
        for(String key : affiliations.keySet()){
            if(affiliations.get(key)==null){
                affiliationsInsert.put(key, new Account(Name=key));
            }
        }

        List<Database.SaveResult> saveResults;

        //Insertar affiliations
        saveResults = Database.insert(affiliationsInsert.values(), false);
        for(Database.SaveResult saveResult : saveResults) {
            if(!saveResult.isSuccess()) {
            	for(Database.Error saveError : saveResult.getErrors()) 
                	System.debug('StripeGetChargesBatch - Affiliation Account Insert Error: ' + saveError.getMessage());
        	}
        }

        //Setear el id al map affiliations
        for(Account acc : affiliationsInsert.values()){
            if(acc.Id!=null)
                affiliations.put(acc.Name.tolowercase(), acc.Id);
        }
        
        //Buscar contacts existentes para actualizarlos
        String auxEmail='';
        for(Contact contact : [select Id, Email, npe01__AlternateEmail__c, npe01__HomeEmail__c, 
                                        npe01__WorkEmail__c, Agency_Contact_Email__c, AccountId , npsp__Primary_Affiliation__c,
                                        MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry 
                                    from Contact 
                                    where Email in: emailContacts.keySet() or npe01__AlternateEmail__c in: emailContacts.keySet()
                                        or npe01__HomeEmail__c in: emailContacts.keySet() or npe01__WorkEmail__c in: emailContacts.keySet()
                                        or Agency_Contact_Email__c in: emailContacts.keySet()]){
            /*if(contact.Email!=null && emailContacts.containskey(contact.Email.tolowercase())){
                emailContacts.put(contact.Email, contact.Id);
                emailAccounts.put(contact.Email, contact.AccountId);
            } else if(contact.npe01__AlternateEmail__c!=null && emailContacts.containskey(contact.npe01__AlternateEmail__c.tolowercase())){
                emailContacts.put(contact.npe01__AlternateEmail__c, contact.Id);
                emailAccounts.put(contact.npe01__AlternateEmail__c, contact.AccountId);
            } else if(contact.npe01__HomeEmail__c!=null && emailContacts.containskey(contact.npe01__HomeEmail__c.tolowercase())){
                emailContacts.put(contact.npe01__HomeEmail__c, contact.Id);
                emailAccounts.put(contact.npe01__HomeEmail__c, contact.AccountId);
            } else if(contact.npe01__WorkEmail__c!=null && emailContacts.containskey(contact.npe01__WorkEmail__c.tolowercase())){
                emailContacts.put(contact.npe01__WorkEmail__c, contact.Id);
                emailAccounts.put(contact.npe01__WorkEmail__c, contact.AccountId);
            } else if(contact.Agency_Contact_Email__c!=null && emailContacts.containskey(contact.Agency_Contact_Email__c.tolowercase())){
                emailContacts.put(contact.Agency_Contact_Email__c, contact.Id);
                emailAccounts.put(contact.Agency_Contact_Email__c, contact.AccountId);
            }*/
            if(contact.Email!=null && emailContacts.containskey(contact.Email.tolowercase())) auxEmail = contact.Email.tolowercase();
            else if(contact.npe01__AlternateEmail__c!=null && emailContacts.containskey(contact.npe01__AlternateEmail__c.tolowercase())) auxEmail = contact.npe01__AlternateEmail__c.tolowercase();
            else if(contact.npe01__HomeEmail__c!=null && emailContacts.containskey(contact.npe01__HomeEmail__c.tolowercase())) auxEmail = contact.npe01__HomeEmail__c.tolowercase();
            else if(contact.npe01__WorkEmail__c!=null && emailContacts.containskey(contact.npe01__WorkEmail__c.tolowercase())) auxEmail = contact.npe01__WorkEmail__c.tolowercase();
            else if(contact.Agency_Contact_Email__c!=null && emailContacts.containskey(contact.Agency_Contact_Email__c.tolowercase())) auxEmail = contact.Agency_Contact_Email__c.tolowercase();
            emailContacts.put(auxEmail, contact.Id);
            emailAccounts.put(auxEmail, contact.AccountId);

            //seteo de address mailing u other address
            //System.debug('auxEmail: ' + auxEmail);
            //System.debug('mapContacts.get(auxEmail): ' + mapContacts.get(auxEmail));
            auxContact = mapContacts.get(auxEmail);
            
            if(String.IsNotBlank(auxContact.Stripe_Primary_Affiliation__c) && affiliations.get(auxContact.Stripe_Primary_Affiliation__c)!=null)
                    auxContact.npsp__Primary_Affiliation__c = affiliations.get(auxContact.Stripe_Primary_Affiliation__c);

            if(String.IsNotBlank(auxContact.MailingStreet) || String.IsNotBlank(auxContact.MailingCity) || String.IsNotBlank(auxContact.MailingState) || 
                                String.IsNotBlank(auxContact.MailingPostalCode) || String.IsNotBlank(auxContact.MailingCountry)) {
                if(String.IsNotBlank(contact.MailingStreet) || String.IsNotBlank(contact.MailingCity) || String.IsNotBlank(contact.MailingState)
                        || String.IsNotBlank(contact.MailingPostalCode) || String.IsNotBlank(contact.MailingCountry))
                    contactsUpdate.put(auxEmail, new Contact(Id=contact.Id, npsp__Primary_Affiliation__c=auxContact.npsp__Primary_Affiliation__c, 
                                                            OtherStreet=auxContact.MailingStreet, OtherCity=auxContact.MailingCity, OtherState=auxContact.MailingState, 
                                                            OtherPostalCode=auxContact.MailingPostalCode, OtherCountry=auxContact.MailingCountry));
                else
                    contactsUpdate.put(auxEmail, new Contact(Id=contact.Id, npsp__Primary_Affiliation__c=auxContact.npsp__Primary_Affiliation__c, 
                                                            MailingStreet=auxContact.MailingStreet, MailingCity=auxContact.MailingCity, MailingState=auxContact.MailingState, 
                                                            MailingPostalCode=auxContact.MailingPostalCode, MailingCountry=auxContact.MailingCountry));
            }else
                contactsUpdate.put(auxEmail, new Contact(Id=contact.Id, npsp__Primary_Affiliation__c=auxContact.npsp__Primary_Affiliation__c));
        }

        //actualizar contacts (address and npsp__Primary_Affiliation__c)
        saveResults = Database.update(contactsUpdate.values(), false);
        for(Database.SaveResult saveResult : saveResults) {
            if(!saveResult.isSuccess()) {
            	for(Database.Error saveError : saveResult.getErrors()) 
                	System.debug('StripeGetChargesBatch - Contact Update Error: ' + saveError.getMessage());
        	}
        }
        
        //Agregar contactos y accounts para insertar
        String auxNameFormula;
        for(String key : emailContacts.keySet()){
            if(emailContacts.get(key)==null){
                auxContact = mapContacts.get(key);
                if(String.IsNotBlank(auxContact.Stripe_Primary_Affiliation__c) && affiliations.get(auxContact.Stripe_Primary_Affiliation__c)!=null)
                    auxContact.npsp__Primary_Affiliation__c = affiliations.get(auxContact.Stripe_Primary_Affiliation__c);
                contactsInsert.put(key, new Contact(FirstName=auxContact.FirstName, LastName=auxContact.LastName, npsp__Primary_Affiliation__c=auxContact.npsp__Primary_Affiliation__c, 
                                                        MailingStreet=auxContact.MailingStreet, MailingCity=auxContact.MailingCity, MailingState=auxContact.MailingState, 
                                                        MailingPostalCode=auxContact.MailingPostalCode, MailingCountry=auxContact.MailingCountry, 
                                                        Email=key, RecordTypeId=recordTypeContact));

                auxNameFormula = String.IsNotBlank(auxContact.FirstName) ? auxContact.FirstName + ' ' + auxContact.LastName + ' Household' : auxContact.LastName + ' Household';
                accountsInsert.put(key, new Account(Name=auxNameFormula));
            }
        }

        //Insertar accounts
        saveResults = Database.insert(accountsInsert.values(), false);
        for(Database.SaveResult saveResult : saveResults) {
            if(!saveResult.isSuccess()) {
            	for(Database.Error saveError : saveResult.getErrors()) 
                	System.debug('StripeGetChargesBatch - Account Insert Error: ' + saveError.getMessage());
        	}
        }

        //Setear el accountid a los contactos a insertar
        for(Contact contact : contactsInsert.values()){
            if(accountsInsert.get(contact.Email)!=null && accountsInsert.get(contact.Email).Id!=null){
                contact.AccountId = accountsInsert.get(contact.Email).Id;
            }
        }

        //Insertar contactos
        saveResults = Database.insert(contactsInsert.values(), false);
        for(Database.SaveResult saveResult : saveResults) {
            if(!saveResult.isSuccess()) {
            	for(Database.Error saveError : saveResult.getErrors()) 
                	System.debug('StripeGetChargesBatch - Contact Insert Error: ' + saveError.getMessage());
        	}
        }
        
        //Setear el id al map emailContacts y emailAccounts
        for(Contact contact : contactsInsert.values()){
            if(contact.Id!=null){
                emailContacts.put(contact.Email, contact.Id);
                emailAccounts.put(contact.Email, contact.AccountId);
            }
        }
        
        //setear el contacto y account relacionado a las opps
        for(Opportunity o : opps.values()){
        	if(o.Receipt_Email__c!=null)
            {
             	if(emailContacts.get(o.Receipt_Email__c)!=null) 
                	o.npsp__Primary_Contact__c = emailContacts.get(o.Receipt_Email__c);
                    //System.debug('Add: ' + acc.Name + '-' + acc.Id);

                if(emailAccounts.get(o.Receipt_Email__c)!=null) 
                	o.AccountId = emailAccounts.get(o.Receipt_Email__c);
            }
      	}
        
        List<Database.UpsertResult> upsertResults;

        //upsertear opps
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
            if(this.hasMoreItems) System.scheduleBatch(new StripeGetChargesBatch(instance, pageSize, initAfterRecord), 'StripeGetChargesBatch-' + initAfterRecord, 1, 100);
            //else Database.executeBatch(new ShopifyCheckoutBatch(instance, isAll, pageSize));
        }
    }
    
}