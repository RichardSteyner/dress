public class StripeConnection {
    
    //public static StripeAPI__c authentication = StripeAPI__c.getOrgDefaults();
    
    public static String getStripeEntity(String instance, String entity, String filters){
        StripeAPI_List__c authentication = StripeAPI_List__c.getValues(instance);
        //Blob headerValue = Blob.valueOf(authentication.API_Key__c + ':' + authentication.Password__c);
        String authorizationHeader = 'Bearer ' + authentication.API_Key__c;
        HttpRequest request = new HttpRequest();
        request.setEndpoint(authentication.Base_URL__c + entity + (String.isNotBlank(filters) ? '?' + filters : ''));
		//System.debug(endpoint);
        request.setHeader('Accept','application/json');
        request.setHeader('Content-type', 'application/json');
        request.setHeader('Authorization', authorizationHeader);
        request.setMethod('GET');
        request.setTimeout(120000);
        Http http = new Http();
        HTTPResponse response;
        try{
            if(!Test.isRunningTest()){
                response = http.send(request);
                System.debug('->StripeConnection= ' + authentication.Base_URL__c + ', entity = ' +  entity + ', filters = ' +  filters + ') => Response Status Code: ' + response.getStatusCode() + ', Response Body: ' + (String.isNotEmpty(response.getBody()) ? response.getBody().left(255) : ''));
            }else{
                response = new HTTPResponse();
                response.setStatusCode(200);
                if(entity.equalsIgnoreCase('customers')) response.setBody('');
                else if(entity.equalsIgnoreCase('products')) response.setBody('');
        	}
        }
        catch(Exception e){
            response = new HTTPResponse();
            response.setStatusCode(500);
            System.debug('-->StripeConnection= ' + authentication.Base_URL__c + ', entity = ' +  entity + ') - Callout Exception: ' + e.getMessage());
        }
        return response.getBody();
    }
                                                                    
 	public static String getShopifyID(String idS, String instance){
    	return idS.contains(instance) ? idS.substring(instance.length()+1, idS.length()) : ids;
    }

}