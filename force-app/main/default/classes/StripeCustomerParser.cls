global class StripeCustomerParser {
    
    public String id {get; set;}
    public String email {get; set;}
    public String name {get; set;}
    public Metadata metadata {get; set;}

    public class Metadata {
        public String Email {get; set;}
        public String Name {get; set;}
    }

    public String getEmail(){
        return String.IsNotBlank(email) ? email.tolowercase() : metadata!=null && String.IsNotBlank(metadata.Email) ? metadata.Email.tolowercase() : '';
    }

    public String getName(){
        return String.IsNotBlank(name) ? name : metadata!=null && String.IsNotBlank(metadata.Name) ? metadata.Name : '';
    }

    public String getFirstName() {
        try{
            String auxName = getName();
            if(String.IsNotBlank(auxName))
            {
                Integer pos = auxName.indexOf(' ');
                if(pos!=-1)
                	return auxName.substring(0, pos);
            }
        }catch(Exception e){
            System.debug('Exception getFirstName: ' + e.getMessage());
        }
        return '';
    }
    
    public String getLastName() {
        try{
            String auxName = getName();
            if(String.IsNotBlank(auxName))
            {
                Integer pos = auxName.indexOf(' ');
                if(pos!=-1)
                	return auxName.substring(pos+1, auxName.length());
            }
        }catch(Exception e){
            System.debug('Exception Long a Date: ' + e.getMessage());
        }
        return null;
    }

    public String getNameFromEmail(){
        String auxEmail = String.IsNotBlank(email) ? email : metadata!=null && String.IsNotBlank(metadata.Email) ? metadata.Email : '';
        return String.IsNotBlank(auxEmail) 
                        ? (auxEmail.contains('@') ? auxEmail.substring(0, auxEmail.indexOf('@')) : auxEmail) 
                        : 'Name Null';
    }
    
}
