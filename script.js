window.addEventListener("message", function(event) {
    const data = event.data;

    if (data.type === "vignette") {
        const vignette = document.getElementById("vignette");

        if (data.state) {
            vignette.style.opacity = data.opacity || 1.0;
        } else {
            vignette.style.opacity = 0;
        }
    }
});