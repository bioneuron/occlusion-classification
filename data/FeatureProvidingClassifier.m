classdef FeatureProvidingClassifier < Classifier
    % Classifier that retrieves the features from previous runs.
    
    properties
        providedClassifier
        caches
    end
    
    methods
        function self = FeatureProvidingClassifier(...
                occlusionData, dataSelection, providedClassifier)
            self.providedClassifier = providedClassifier;
            dir = './data/OcclusionModeling/features/';
            [filePrefix, fileSuffix, loadFeatures] = ...
                self.getFileDirectives(providedClassifier);
            self.caches = containers.Map(...
                {char(RunType.Train), char(RunType.Test)}, ...
                {self.createWholeCache(...
                [dir 'klab325_orig/'], ...
                filePrefix, fileSuffix, loadFeatures, dataSelection, ...
                occlusionData), ...
                self.createOccludedCache(...
                [dir 'data_occlusion_klab325v2/'], ...
                filePrefix, fileSuffix, loadFeatures, dataSelection)});
        end
        
        function name = getName(self)
            name = self.providedClassifier.getName();
            name = strrep(name, 'alexnet-', 'caffenet_');
        end
        
        function fit(self, features, labels)
            self.providedClassifier.fit(features,labels);
        end
        
        function labels = predict(self, features)
            labels = self.providedClassifier.predict(features);
        end
        
        function features = extractFeatures(self, ids, runType)
            boxedFeatures = cell(length(ids), 1);
            cache = self.caches(char(runType));
            for i = 1:length(ids)
                cachedFeatures = cache(ids(i));
                boxedFeatures{i} = cachedFeatures{:};
            end
            features = cell2mat(boxedFeatures);
        end
    end
    
    methods (Access=private)
        function cache = createWholeCache(~, ...
                dir, filePrefix, fileSuffix, ...
                loadFeatures, dataSelection, occlusionData)
            cache = containers.Map(...
                'KeyType', 'double', 'ValueType', 'any');
            filePath = [dir filePrefix '1-325' fileSuffix];
            features = loadFeatures(filePath);
            for id = dataSelection
                cache(id) = {features(occlusionData.pres(id), :)};
            end
        end
        
        function cache = createOccludedCache(~, ...
                dir, filePrefix, fileSuffix, ...
                loadFeatures, dataSelection)
            cache = containers.Map(...
                'KeyType', 'double', 'ValueType', 'any');
            minFile = 1000 * floor(min(dataSelection) / 1000) + 1;
            maxFile = 1000 * ceil(max(dataSelection) / 1000) + 1;
            for fileLower = minFile:1000:maxFile-1000
                fileUpper = fileLower+999;
                filePath = [dir filePrefix num2str(fileLower) '-' ...
                    num2str(fileUpper) fileSuffix];
                features = loadFeatures(filePath);
                for id = dataSelection(dataSelection >= fileLower ...
                        & dataSelection <= fileUpper)
                    cache(id) = {features(id - fileLower + 1, :)};
                end
            end
        end
        
        function features = loadMat(~, filePath)
            data = load(filePath);
            features = data.features;
        end
        
        function [filePrefix, fileSuffix, loadFeatures] = ...
                getFileDirectives(self, providedClassifier)
            name = self.providedClassifier.getName();
            switch(name)
                case 'alexnet-pool5'
                    filePrefix = 'caffenet_pool5_ims_';
                    fileSuffix = '.txt';
                    loadFeatures = @(file) dlmread(file, ' ', 0, 1);
                case 'alexnet-fc7'
                    filePrefix = 'caffenet_fc7_ims_';
                    fileSuffix = '.txt';
                    loadFeatures = @(file) dlmread(file, ' ', 0, 1);
                case 'hmax'
                    filePrefix = 'hmax_ims_';
                    fileSuffix = '.mat';
                    loadFeatures = @self.loadMat;
                otherwise
                    if isempty(regexp(name, ...
                            ['^('...
                            '(pixels)'...
                            '|(((alexnet)|(caffenet))(\-|_)((pool5)|(fc7)))'...
                            '|(hmax)'...
                            ')'...
                            '\-hop\-threshold[0-9]+(\.[0-9]+)?'...
                            '$']))
                        error(['Unknown classifier ' providedClassifier.getName()]);
                    end
                    
                    filePrefix = [strrep(name, 'alexnet-', 'caffenet_') '_'];
                    fileSuffix = '.mat';
                    loadFeatures = @self.loadMat;
            end
        end
    end
end
