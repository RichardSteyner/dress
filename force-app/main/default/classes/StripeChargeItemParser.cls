global class StripeChargeItemParser {

        public String id {get; set;}
        public Decimal amount {get; set;}
        public Decimal amount_captured {get; set;}
        public Decimal amount_refunded {get; set;}
        public BillingDatails billing_details {get; set;}
        public Boolean captured {get; set;}
        public Long created {get; set;}
        public String currency_x {get; set;}
        public String customer {get; set;}
        public String description {get; set;}
        public Boolean disputed {get; set;}
        public String invoice {get; set;}
        public Metadata metadata {get; set;}
        public Outcome outcome {get; set;}
        public Boolean paid {get; set;}
        public String payment_method {get; set;}
        public String receipt_email {get; set;}
        public String receipt_number {get; set;}
        public String receipt_url {get; set;}
        public Boolean refunded {get; set;}
        public Source source {get; set;}
        public String status {get; set;}
    
    public class BillingDatails {
    	public Address address {get; set;}  
        public String email {get; set;} 
        public String name {get; set;}
        public String phone {get; set;}
    }
    
    public class Address {
    	public String city {get; set;}  
        public String country {get; set;}  
        public String line1 {get; set;}  
        public String line2 {get; set;}  
        public String postal_code {get; set;}  
        public String state {get; set;}  
    }
    
    public class Metadata {
        public String Notes {get; set;}
        public String Campaign {get; set;}
        public String Country {get; set;}
        public String Security_Group {get; set;}
        public String Donation_Type {get; set;}
        public String Company {get; set;}
    }
    
    public class Outcome {
        public String seller_message {get; set;}
    }
    
    public class Source {
        public String id {get; set;}
        public String address_city {get; set;}  
        public String address_country {get; set;}  
        public String address_line1 {get; set;}  
        public String address_line1_check {get; set;}  
        public String address_line2 {get; set;}  
        public String address_state {get; set;} 
        public String address_zip {get; set;} 
        public String address_zip_check {get; set;} 
        public String brand {get; set;} 
        public String country {get; set;} 
        public String customer {get; set;} 
        public String cvc_check {get; set;} 
        public String funding {get; set;} 
        public String name {get; set;} 
    }

    public String getEmail(){
        return receipt_email!=null ? receipt_email.tolowercase() : '';
    }
    
    public Date getCloseDate(){
        try{
            if(created!=null){
                Datetime aux = Datetime.newInstance(created*1000);
                return Date.newInstance(aux.yearGmt(), aux.monthGmt(), aux.dayGmt());
            }
        }catch(Exception e){
            System.debug('Exception in created field convert: ' + e.getMessage());
        }
        return Date.today();
    }

    public String getFirstName() {
        try{
            if(billing_details!=null && billing_details.name!=null)
            {
                Integer pos = billing_details.name.indexOf(' ');
                if(pos!=-1)
                	return billing_details.name.substring(0, pos);
            }
        }catch(Exception e){
            System.debug('Exception getFirstName: ' + e.getMessage());
        }
        return '';
    }
    
    public String getLastName() {
        try{
            if(billing_details!=null && billing_details.name!=null)
            {
                Integer pos = billing_details.name.indexOf(' ');
                if(pos!=-1)
                	return billing_details.name.substring(pos+1, billing_details.name.length());
            }
        }catch(Exception e){
            System.debug('Exception Long a Date: ' + e.getMessage());
        }
        return null;
    }

    public String getName(){
        /*if(billing_details!=null && billing_details.name!=null)
            return billing_details.name;*/
        return receipt_email!=null 
                        ? (receipt_email.contains('@') ? receipt_email.substring(0, receipt_email.indexOf('@')) : receipt_email) 
                        : 'Name Null';
    }

    public String getStreet(){
        return billing_details!=null && billing_details.address!=null ? billing_details.address.line1 : null;
    }

    public String getCity(){
        return billing_details!=null && billing_details.address!=null ? billing_details.address.city : null;
    }

    public String getState(){
        return billing_details!=null && billing_details.address!=null ? billing_details.address.state : null;
    }

    public String getPostalCode(){
        return billing_details!=null && billing_details.address!=null ? billing_details.address.postal_code : null;
    }

    public String getCountry(){
        return billing_details!=null && billing_details.address!=null ? billing_details.address.country : null;
    }

    public boolean addressNotEmpty(){
        return String.IsNotBlank(getStreet()) || String.IsNotBlank(getCity()) || String.IsNotBlank(getState()) || 
                                String.IsNotBlank(getPostalCode()) || String.IsNotBlank(getCountry());
    }
    
}