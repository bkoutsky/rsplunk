JAR_SPLUNK = splunk-1.1.jar
CLASSPATH = .:$(JAR_SPLUNK)

JAVAC = javac
JAVAC_FLAGS = -g -cp $(CLASSPATH)

.SUFFIXES: .java .class

.java.class:
	$(JAVAC) $(JAVAC_FLAGS) $*.java

JAVA_SRC = \
        Splunk.java

all: build

classes: $(JAVA_SRC:.java=.class)

clean:
	$(RM) *.class

build: classes

jrun: build
	java -cp $(CLASSPATH) Splunk ${SPLUNK_USERNAME} ${SPLUNK_PASSWORD} ${SPLUNK_HOST}


rrun: build
	R rsplunk.R
