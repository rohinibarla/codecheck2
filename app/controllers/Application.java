package controllers;

import java.util.regex.*;

import play.mvc.Controller;
import play.mvc.Http;
import play.mvc.Http.RequestBody;
import play.mvc.Result;
import models.Util;

public class Application extends Controller {
   private Pattern dfPattern = Pattern.compile("(?s:.*?(?<percent>[0-9]+)%.*)");
   
    public Result health(Http.Request request) {
       try {
          String df = com.horstmann.codecheck.Util.runProcess("/bin/df /", 1000);
          String mp = com.horstmann.codecheck.Util.runProcess("/usr/bin/mpstat 2 1", 3000);
          Matcher matcher = dfPattern.matcher(df);
          if (matcher.matches()) {
             String percent =  matcher.group("percent");
             if (Integer.parseInt(percent) > 95)
                return internalServerError("disk " + percent + "% full");
             // TODO: Analyze output
             // http://stackoverflow.com/questions/9229333/how-to-get-overall-cpu-usage-e-g-57-on-linux
             return ok("CodeCheck\n" + df + "\n" + mp);
          }
          else return ok("df output doesn't match pattern: " + df);
       } catch (Throwable ex) {
          return internalServerError(Util.getStackTrace(ex));
       }
    }   
    
    public Result echo(Http.Request request) {
    	RequestBody body = request.body();
    	return ok("Received: " + body.asJson());
    }
}
