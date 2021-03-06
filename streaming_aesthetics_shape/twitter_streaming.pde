import twitter4j.conf.*;
import twitter4j.api.*;
import twitter4j.*;
import java.util.*;
import java.util.regex.*;


/*******************************************************************************
  Streaming query.
*******************************************************************************/

ConfigurationBuilder cb;
Query query;

// Set up the twitter connection using config from configuration.properties

TwitterStream makeTwitterStream() {
  Properties p = new Properties();
  InputStream propStream = openStream("configuration.properties");
  try {
    p.load(propStream);
  } catch (IOException e)
  {
    System.out.println(e);
    noLoop();
  }
  cb = new ConfigurationBuilder();
  cb.setOAuthConsumerKey((String)p.getProperty("consumerKey"));
  cb.setOAuthConsumerSecret((String)p.getProperty("consumerSecret"));
  cb.setOAuthAccessToken((String)p.getProperty("accessToken"));
  cb.setOAuthAccessTokenSecret((String)p.getProperty("accessSecret"));
  return new TwitterStreamFactory(cb.build()).getInstance();
}

// Create the object that handles matches on the Twitter stream

StatusListener createStatusListener() {
 return new StatusListener(){
    public void onStatus(Status status){
      insertShapes (status.getText());
    }
    public void onDeletionNotice(StatusDeletionNotice statusDeletionNotice) {}
    public void onTrackLimitationNotice(int numberOfLimitedStatuses) {}
    public void onStallWarning(StallWarning warning) {}
    public void onScrubGeo(long userId, long upToStatusId) {}
    public void onException(Exception ex) {
      ex.printStackTrace();
    }
  };
}

// Tie the Twitter stream search to its handler

TwitterStream createFilteredStream(StatusListener listener) {
  TwitterStream ts = makeTwitterStream();
  FilterQuery fq = new FilterQuery();
  fq.track(shapes);

  ts.addListener(listener);
  ts.filter(fq);
  return ts;
}


/*******************************************************************************
  The list of shapes found in Tweets but not yet being drawn.
*******************************************************************************/

// The list of shapes created by the tweet handler ready for the draw thread
LinkedList shapesToAdd;

// Queue a shape

void queueShapeToAdd(String shape) {
  synchronized (shapesToAdd) {
    shapesToAdd.addFirst(makeShape(shape));
  }
}

// Get and remove the next shape from the queue

Shape nextShapeToAdd() {
  // Caller must synchronize. Avoid threadlock...
  return (Shape)shapesToAdd.removeLast();
}

// Check whether we have any shapes queued

Boolean haveShapesToAdd() {
  return ! shapesToAdd.isEmpty();
}

/*******************************************************************************
  Tweet processing
*******************************************************************************/

// Insert all shapes found in a tweet into the add queue as shapes to be drawn

//TODO: Handle mentions of a single shape multiple times?
void insertShapes (String message) {
  // Java String contains () isn't case insensitive
  String lowercaseMessage = message.toLowerCase();
  for (int i = 0; i < shapes.length; i++) {
    if (lowercaseMessage.contains(shapes[i])) {
      queueShapeToAdd(shapes[i]);
    }
  }
}

// The streaming API processor
TwitterStream twitterStream;

void initializeStatusListener (String[] terms, String user, String password) {
  ConfigurationBuilder builder = new ConfigurationBuilder();
  builder.setUser(user);
  builder.setPassword(password);
  twitterStream = new TwitterStreamFactory(builder.build()).getInstance();
  StatusListener listener = new StatusListener(){
    public void onStatus(Status status) {
      System.out.println(status.getUser().getName() + " : " + status.getText());
      insertShapes(status.getText());
    }
    public void onDeletionNotice(StatusDeletionNotice statusDeletionNotice) {}
    public void onTrackLimitationNotice(int numberOfLimitedStatuses) {}
    public void onStallWarning(StallWarning warning) {}
    public void onScrubGeo(long lat, long lon) {}
    public void onException(Exception ex) {
      ex.printStackTrace();
    }
  };
  twitterStream.addListener(listener);
  FilterQuery query = new FilterQuery(0, null, terms);
  twitterStream.filter(query);
}

