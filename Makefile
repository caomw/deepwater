UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S), Darwin)
	JAVA_INCLUDE=/System/Library/Frameworks/JavaVM.framework/Headers
	JNI_INCLUDE=$(JAVA_INCLUDE)
else
	#JAVA_INCLUDE=/usr/lib/jvm/java-1.8.0-openjdk-amd64/include/linux
	#JNI_INCLUDE=/usr/lib/jvm/java-1.8.0-openjdk-amd64/include
	JAVA_INCLUDE=/usr/lib/jvm/java-8-oracle/include/linux/
	JNI_INCLUDE=/usr/lib/jvm/java-8-oracle/include/
endif

MXNET_SRCS=src/executor.cxx src/kvstore.cxx src/operator.cxx src/symbol.cxx src/io.cxx src/ndarray.cxx src/optimizer.cxx

MXNET_OBJS=$(MXNET_SRCS:.cxx=.o)

SRCS=mlp.cxx image_pred.cxx network_def.cxx image_train.cxx

OBJS=$(SRCS:.cxx=.o)

TARGET=libNative.so

CXX=g++

INCLUDE=-I$(JAVA_INCLUDE) -I$(JNI_INCLUDE) -Iinclude

MXLIB=-L./mxnet/lib -lmxnet

LDFLAGS=-Wl,-rpath,/tmp $(MXLIB)

CXXFLAGS :=-std=c++11 -O3

ifndef CUDA_PATH
	CXXFLAGS += -DNO_GPU
else
	CXXFLAGS += -DGPU
endif

.PHONY: depend clean all

DEPS := $(OBJS:.o=.d)

all: swig $(MXNET_OBJS) $(OBJS) $(TARGET)

-include $(DEPS)

$(MXNET_OBJS): %.o : %.cxx
	$(CXX) -c -fPIC $(CXXFLAGS) $(INCLUDE) $< -o $@

$(OBJS): %.o : %.cxx
	$(CXX) -c -fPIC $(CXXFLAGS) $(INCLUDE) $< -MM -MF $(patsubst %.o,%.d,$@)
	$(CXX) -c -fPIC $(CXXFLAGS) $(INCLUDE) $< -o $@

swig:
	swig -c++ -java -package water.gpu deepwater.i

deepwater_wrap.o:
	$(CXX) -c -fPIC $(CXXFLAGS) $(INCLUDE) deepwater_wrap.cxx -o deepwater_wrap.o

$(TARGET): $(MXNET_OBJS) $(OBJS) deepwater_wrap.o
	rm -rf $(TARGET)
	$(CXX) -shared $(MXNET_OBJS) $(OBJS) deepwater_wrap.o -o $(TARGET) $(LDFLAGS)

test: mlp_test lstm_test lenet_test inception_test vgg_test googlenet_test resnet_test alexnet_test

mlp_test: $(TARGET) clean_test
	$(CXX) -c -fPIC $(CXXFLAGS) $(INCLUDE) ./test/mlp_test.cxx -o mlp_test.o
	$(CXX) -o mlp_test mlp_test.o $(MXNET_OBJS) $(OBJS) $(MXLIB)

lstm_test: $(TARGET) clean_test
	$(CXX) -c -fPIC $(CXXFLAGS) $(INCLUDE) ./test/lstm_test.cxx -o lstm_test.o
	$(CXX) -o lstm_test lstm_test.o network_def.o $(MXNET_OBJS) $(MXLIB)

lenet_test: $(TARGET) clean_test
	$(CXX) -c -fPIC $(CXXFLAGS) $(INCLUDE) ./test/lenet_test.cxx -o lenet_test.o
	$(CXX) -o lenet_test lenet_test.o network_def.o $(MXNET_OBJS) $(MXLIB)

inception_test: $(TARGET) clean_test
	$(CXX) -c -fPIC $(CXXFLAGS) $(INCLUDE) ./test/inception_test.cxx -o inception_test.o
	$(CXX) -o inception_test inception_test.o network_def.o $(MXNET_OBJS) $(MXLIB)

vgg_test: $(TARGET) clean_test
	$(CXX) -c -fPIC $(CXXFLAGS) $(INCLUDE) ./test/vgg_test.cxx -o vgg_test.o
	$(CXX) -o vgg_test vgg_test.o network_def.o $(MXNET_OBJS) $(MXLIB)

googlenet_test: $(TARGET) clean_test
	$(CXX) -c -fPIC $(CXXFLAGS) $(INCLUDE) ./test/googlenet_test.cxx -o googlenet_test.o
	$(CXX) -o googlenet_test googlenet_test.o network_def.o $(MXNET_OBJS) $(MXLIB)

resnet_test: $(TARGET) clean_test
	$(CXX) -c -fPIC $(CXXFLAGS) $(INCLUDE) ./test/resnet_test.cxx -o resnet_test.o
	$(CXX) -o resnet_test resnet_test.o network_def.o $(MXNET_OBJS) $(MXLIB)

alexnet_test: $(TARGET) clean_test
	$(CXX) -c -fPIC $(CXXFLAGS) $(INCLUDE) ./test/alexnet_test.cxx -o alexnet_test.o
	$(CXX) -o alexnet_test alexnet_test.o network_def.o $(MXNET_OBJS) $(MXLIB)

lint:
	python lint.py deepwater cpp *.cxx *.hpp ./include ./src

pkg: all $(TARGET)
	javac *.java
	rm -rf water/gpu
	mkdir -p water/gpu
	mv *.class ./water/gpu
ifeq ($(UNAME_S), Darwin)
	install_name_tool -change lib/libmxnet.so @loader_path/libmxnet.so libNative.so
endif
	cp ./libNative.so ./water/gpu
	cp mxnet/lib/libmxnet.so ./water/gpu
	jar -cvf water.gpu.jar ./water

java_test: 
	javac -cp water.gpu.jar java/h2o/deepwater/test/InceptionCLI.java
	java -cp water.gpu.jar:java h2o.deepwater.test.InceptionCLI $(PWD)/Inception $(PWD)/test/test2.jpg 

.PHONY: java_test clean clean_test

clean: clean_test
	rm -rf $(MXNET_OBJS) $(OBJS) $(TARGET) *_wrap.cxx *_wrap.o *.d

clean_test:
	rm -rf *_test.o *_test water*

