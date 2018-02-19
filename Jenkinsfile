// Quickly test syntax and formatting before accepting change on Gerrit.
// TODO: Use Docker ?

node('rvm&&golang&&redis') {
  withRvm('ruby-2.2.9') {
	stage('Checkout from git') {	
      checkout scm
      sh '#!/bin/bash\n[[ -f Gemfile.lock ]] && rm Gemfile.lock; true'
  	}

	stage('Install gems') {
	  sh 'gem install bundler'
	  sh 'bundle install --path vendor/bundle'
	  withEnv(["PATH=/usr/local/go/bin:$PATH"]) {
	  	sh './build.sh'
	  }
    }

	stage('Run tests') {
	  withEnv([
	  	"SHOW_LOGGER_ALL=true",
	  	"COVERAGE=true"
	  ]) {
	    rake 'pact:verify'	
      	rake 'tests'
      }
	}

	stage('Build project') {
      rake 'build'
    }

	//stage('Live test') {
    //  sh 'test/live_test.sh ${jenkins_working_dir}'
    //}
  }
}

// Helper functions
def withRvm(version, cl) {
    withRvm(version, "executor-${env.EXECUTOR_NUMBER}") {
        cl()
    }
}

def withRvm(version, gemset, cl) {
    RVM_HOME="/usr/local/rvm"    
    paths = [
        "$RVM_HOME/gems/$version@$gemset/bin",
        "$RVM_HOME/gems/$version@global/bin",
        "$RVM_HOME/gems/$version/bin",
        "$RVM_HOME/rubies/$version/bin",
        "$RVM_HOME/bin",
        "${env.PATH}"
    ]
    def path = paths.join(':')
    withEnv(["PATH=${env.PATH}:$RVM_HOME", "RVM_HOME=$RVM_HOME"]) {
    	sh "#!/bin/bash\nset +x; source /etc/profile.d/rvm.sh; rvm use $version@$gemset"
    }
    withEnv([
        "PATH=$path",
        "GEM_HOME=$RVM_HOME/gems/$version@$gemset",
        "GEM_PATH=$RVM_HOME/gems/$version@$gemset:$RVM_HOME/gems/$version@global",
        "MY_RUBY_HOME=$RVM_HOME/rubies/$version",
        "IRBRC=$RVM_HOME/rubies/$version/.irbrc",
        "RUBY_VERSION=$version"
        ]) {
            cl()
    }
}

def rake(command) {
  sh "bundle exec rake ${command}"
}
