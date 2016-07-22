classdef ContrastResponse < fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol
    
    properties
        amp
        preTime = 1000                  % Spot leading duration (ms)
        stimTime = 500                  % Spot duration (ms)
        tailTime = 1000                 % Spot trailing duration (ms)
        numberOfContrastSteps = 5       % Number of contrast steps (doubled for 'both' directions)
        minContrast = 0.02              % Minimum contrast (0-1)
        maxContrast = 1                 % Maximum contrast (0-1)
        contrastDirection = 'positive'  % Direction of contrast
        spotDiameter = 300              % Spot diameter (um)
        numberOfCycles = 2               % Number of cycles through all contrasts
    end
    
    properties (Hidden)
        ampType
        contrastDirectionType = symphonyui.core.PropertyType('char', 'row', {'both', 'positive', 'negative'})
        contrastValues                  % Linspace range between min and max contrast for given contrast steps
        intensityValues                 % Spot meanLevel * (1 + contrast Values)
        contrast                        % Spot contrast value for current epoch @see prepareEpoch
        intensity                       % Spot intensity value for current epoch @see prepareEpoch
        realNumberOfContrastSteps       % compensate for "both" directions having double steps
    end
    
    methods
        function prepareRun(obj)
            prepareRun@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol(obj);
            
            contrasts = 2.^linspace(log2(obj.minContrast), log2(obj.maxContrast), obj.numberOfContrastSteps);
            
            if strcmp(obj.contrastDirection, 'positive')
                obj.contrastValues = contrasts;
            elseif strcmp(obj.contrastDirection, 'negative')
                obj.contrastValues = -1 * contrasts;
            else % both
                obj.contrastValues = [fliplr(-1 * contrasts), contrasts];
            end
            obj.intensityValues = obj.meanLevel + (obj.contrastValues.* obj.meanLevel);
            obj.realNumberOfContrastSteps = length(obj.intensityValues);
            
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            spotDiameterPix = obj.um2pix(obj.spotDiameter);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.meanLevel);
            
            spot = stage.builtin.stimuli.Ellipse();
            spot.color = obj.intensity;
            spot.radiusX = spotDiameterPix/2;
            spot.radiusY = spotDiameterPix/2;
            spot.position = canvasSize / 2;
            p.addStimulus(spot);
            
            spotVisible = stage.builtin.controllers.PropertyController(spot, 'opacity', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(spotVisible);
            
            obj.addFrameTracker(p);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol(obj, epoch);
            
            index = mod(obj.numEpochsPrepared, obj.realNumberOfContrastSteps);
            if index == 0
                reorder = randperm(obj.realNumberOfContrastSteps);
                obj.contrastValues = obj.contrastValues(reorder);
                obj.intensityValues = obj.intensityValues(reorder);
            end
            
            obj.contrast = obj.contrastValues(index + 1);
            obj.intensity = obj.intensityValues(index + 1);
            epoch.addParameter('contrast', obj.contrast);
            epoch.addParameter('intensity', obj.intensity);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.realNumberOfContrastSteps * obj.numberOfCycles;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.realNumberOfContrastSteps * obj.numberOfCycles;
        end
        
    end
    
end

