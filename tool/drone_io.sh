# -----------------------------------
# Script that builds Dart app and pushes it to gh-pages.
#
# Set following variables:
# -----------------------------------
build_folder='example'
github_repo='git@github.com:marcojakob/dart-dnd.git'

# -----------------------------------
# Build.
# -----------------------------------
pub install
pub build ${build_folder}

# Build the shadow dom example separately because it has a transformer.
cd example/shadow-dom
pub build
cd ../..
rm -rf build/example/shadow-dom
mv example/shadow-dom/build/* build/example/shadow-dom/web/


# -----------------------------------
# Configure git in build subfolder
# -----------------------------------

cd build/${build_folder}
git init
git add .

# -----------------------------------
# Deploy to github pages.
# -----------------------------------
git commit -m 'deploy commit from drone'
git push -f ${github_repo} master:gh-pages