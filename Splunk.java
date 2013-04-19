import com.splunk.Service;
import com.splunk.ServiceArgs;
import com.splunk.Application;
import com.splunk.EntityCollection;


class Splunk {

    public Splunk(String username, String password, String host, int port) {

        // Create a map of arguments and add login parameters
        ServiceArgs loginArgs = new ServiceArgs();
        loginArgs.setUsername(username);
        loginArgs.setPassword(password);
        loginArgs.setHost(host);
        loginArgs.setPort(port);
        
        // Create a Service instance and log in with the argument map
        service = Service.connect(loginArgs);
        // Print installed apps to the console to verify login
    }
    
    public String [] getApps() {
        java.util.Collection<Application> ac = service.getApplications().values();
        String [] titles = new String[ac.size()];

        int i = 0;
        for(Application app: ac) {
            titles[i++] = app.getName();
        }
        
        return titles;
    }


    private Service service;
    

    public Service getService() {
        return service;
    }

    public static void main(String [] args) {
        Splunk splunk = new Splunk(
                  args[0], 
                  args[1], 
                  args[2],
                  8089);
        
//        String [] apps = splunk.getApps();
//        for (String s : apps) {
//            System.out.println(s);
//        }
        
        System.out.println("Starting search");
        Search srch =  new Search(splunk, "search index=gdc | stats count ", "-10min@min", "now");

        while (true) {
            if (!srch.columnize()) continue;

            
            //System.out.print("\033[2J\033[H"); 
            System.out.println("---");

            for (String s: srch.getFieldNames()) {
                System.out.println("field: " + s);
            }
            System.out.println("===");
            try {
                Thread.sleep(200);
            } catch (java.lang.InterruptedException e) {
                // Woooohoooo!!!
            }

            if(!srch.isRunning()) break;
        }

        System.out.println("DONE.");

    }

}
