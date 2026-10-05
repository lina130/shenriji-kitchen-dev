// Loaded after Godot's index.js and before engine.startGame(). The entry tap
// measures the difference between Safari's touch coordinates and DOM geometry.
(function () {
    "use strict";

    let correctionX = 0;
    let correctionY = 0;
    let entryPromise = null;

    function waitForEntry() {
        if (entryPromise !== null) {
            return entryPromise;
        }
        const touchDevice = navigator.maxTouchPoints > 0 || matchMedia("(pointer: coarse)").matches;
        const forcePreview = new URLSearchParams(location.search).has("touch_calibration_preview");
        if (!touchDevice && !forcePreview) {
            entryPromise = Promise.resolve();
            return entryPromise;
        }

        entryPromise = new Promise(function (resolve) {
            const style = document.createElement("style");
            style.textContent = `
                #mobile-entry-calibration {
                    position: fixed; inset: 0; z-index: 10000;
                    display: grid; place-items: center;
                    background: #263e38; color: #f7ead4;
                    touch-action: none; user-select: none;
                    font-family: system-ui, -apple-system, sans-serif;
                }
                #mobile-entry-calibration .entry-stack {
                    display: flex; flex-direction: column; align-items: center;
                    justify-content: center; gap: 13px;
                }
                #mobile-entry-calibration .entry-target {
                    display: grid; place-items: center;
                    width: min(44vh, 176px); height: min(44vh, 176px);
                    min-width: 105px; min-height: 105px;
                    border: 2px solid #ead4a2; border-radius: 999px;
                    background: radial-gradient(circle, #6a9c82 0%, #426b5b 62%, #315246 100%);
                    box-shadow: 0 0 0 10px #e3ca8d22, 0 14px 38px #10231a99;
                    pointer-events: none;
                }
                #mobile-entry-calibration .entry-dot {
                    width: 24px; height: 24px; border: 3px solid #fff8df;
                    border-radius: 50%; background: #efcf88;
                    box-shadow: 0 0 0 6px #f3deaa55;
                }
                #mobile-entry-calibration .entry-label {
                    font-size: clamp(14px, 3.5vh, 20px); font-weight: 700;
                    letter-spacing: .06em;
                }
                #mobile-entry-calibration .entry-rotate {
                    display: none; text-align: center; font-size: 24px; font-weight: 700;
                }
                @media (orientation: portrait) {
                    #mobile-entry-calibration .entry-stack { display: none; }
                    #mobile-entry-calibration .entry-rotate { display: block; }
                }
            `;
            document.head.appendChild(style);

            const overlay = document.createElement("div");
            overlay.id = "mobile-entry-calibration";
            overlay.innerHTML = '<div class="entry-stack"><div class="entry-target"><span class="entry-dot"></span></div><span class="entry-label">点圆心进入</span></div><div class="entry-rotate">↻　请横屏游玩</div>';
            document.body.appendChild(overlay);
            const target = overlay.querySelector(".entry-target");

            function enter(point, event) {
                event.preventDefault();
                if (innerHeight > innerWidth) {
                    return;
                }
                const rect = target.getBoundingClientRect();
                const dx = rect.left + rect.width / 2 - point.clientX;
                const dy = rect.top + rect.height / 2 - point.clientY;
                // A remote tap is likely a miss. The correction is only meant
                // for the uniform Safari viewport offset, not arbitrary taps.
                if (Math.abs(dx) > innerWidth * 0.25 || Math.abs(dy) > innerHeight * 0.46) {
                    return;
                }
                correctionX = Math.abs(dx) < 3 ? 0 : dx;
                correctionY = Math.abs(dy) < 3 ? 0 : dy;
                overlay.remove();
                style.remove();
                resolve();
            }

            overlay.addEventListener("touchstart", function (event) {
                if (event.changedTouches.length > 0) {
                    enter(event.changedTouches[0], event);
                }
            }, { passive: false });
            overlay.addEventListener("mousedown", function (event) {
                if (forcePreview) {
                    enter(event, event);
                }
            });
        });
        return entryPromise;
    }

    window.mobileTouchCalibration = {
        waitForEntry,
        getOffset: function () { return [correctionX, correctionY]; },
    };
}());
