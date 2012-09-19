cd $app_dir
rvm gemset use campanify
git remote rm heroku
git remote add heroku git@heroku.campanify.com:$slug.git           
#git config heroku.account campanify_tech
#git config remote.heroku.url git@heroku.campanify_tech:$slug.git
bundle
git add . 
git commit -am 'clonned'
git push heroku master