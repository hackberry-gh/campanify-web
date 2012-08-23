cd $app_dir
rvm gemset use campanify
heroku accounts:set campanify_tech
git remote rm heroku
git remote add heroku git@heroku.campanify_tech:$slug.git           
bundle
git add . 
git commit -am 'clonned'
git push heroku master