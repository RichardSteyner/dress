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
        public String Campaign {get; set;}
        public String Country {get; set;}
        public String Security_Group {get; set;}
        public String Donation_Type {get; set;}
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

    public String getName(){
        if(billing_details!=null && billing_details.name!=null)
            return billing_details.name;
        return receipt_email!=null ? receipt_email : 'Name Null';
    }
    
}