function emptyfile (file) {
    if ((file.value).isempty){
        console.error("The file is empty");
        return 1;
    }
    return 0;
};
