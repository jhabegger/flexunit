/**
 * Copyright (c) 2009 Digital Primates IT Consulting Group
 * 
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 * 
 * @author     Michael Labriola 
 * @version    
 **/ 
package org.flexunit.runners {
	import flash.events.EventDispatcher;
	import flash.utils.Dictionary;
	
	import org.flexunit.internals.AssumptionViolatedException;
	import org.flexunit.internals.events.ExecutionCompleteEvent;
	import org.flexunit.internals.namespaces.classInternal;
	import org.flexunit.internals.runners.ChildRunnerSequencer;
	import org.flexunit.internals.runners.InitializationError;
	import org.flexunit.internals.runners.model.EachTestNotifier;
	import org.flexunit.internals.runners.statements.IAsyncStatement;
	import org.flexunit.internals.runners.statements.RunAftersClass;
	import org.flexunit.internals.runners.statements.RunBeforesClass;
	import org.flexunit.internals.runners.statements.StatementSequencer;
	import org.flexunit.runner.Description;
	import org.flexunit.runner.IDescription;
	import org.flexunit.runner.IRunner;
	import org.flexunit.runner.manipulation.Filter;
	import org.flexunit.runner.manipulation.ISortable;
	import org.flexunit.runner.manipulation.ISorter;
	import org.flexunit.runner.manipulation.MetadataSorter;
	import org.flexunit.runner.manipulation.NoTestsRemainException;
	import org.flexunit.runner.manipulation.Sorter;
	import org.flexunit.runner.notification.IRunNotifier;
	import org.flexunit.runner.notification.StoppedByUserException;
	import org.flexunit.runners.model.FrameworkMethod;
	import org.flexunit.runners.model.TestClass;
	import org.flexunit.token.AsyncTestToken;
	import org.flexunit.token.ChildResult;
	import org.flexunit.utils.ClassNameUtil;
	
	use namespace classInternal;

	/**
	 * The <code>ParentRunner</code> provides most of the functionality specific to an 
	 * <code>IRunner</code> that implements a "parent node" in the test tree.  It is n
	 * directly used as an <code>IRunner</code>; instead, it is inherited by subclesses
	 * that then implement additional functionality.<p>
	 * 
	 * Subclasses must implement finding the children of the node, describing each child, and
	 * running each child. The <code>ParentRunner</code> will filter and sort children, handle
	 * <code>BeforeClass</code> and <code>AfterClass</code> methods, create a composite
	 * <code>IDescription</code>, and run children sequentially.
	 * 
	 * @see org.flexunit.runners.BlockFlexUnit4ClassRunner
	 * @see org.flexunit.runners.Suite
	 */
	/*
	//TODO: Does not define by a data type like in the java version
	*  //how do the matchups described below happen, or not, instead?
	*  with children defined by objects of some data
	* type {@code T}. (For <code> BlockJUnit4ClassRunner</code>, {@code T} is
	* <code> Method</code> . For <code> Suite</code>, {@code T} is <code> Class</code>.)
	*/
	public class ParentRunner implements IRunner, ISortable {
		/**
		 * @private
		 */
		protected static const EACH_NOTIFIER:String = "eachNotifier";
		
		/**
		 * @private
		 */
		private var _testClass:TestClass;
		/**
		 * @private
		 */
		private var filterRef:Filter = null;
		/**
		 * @private
		 */
		private var sorter:ISorter = MetadataSorter.META;
		/**
		 * @private
		 */
		private var filteredChildren:Array;
		/**
		 * @private
		 */
		private var childrenFiltered:Boolean = false;
		
		/**
		 * @private
		 */
		private var cachedDescription:IDescription;
		
		/**
		 * Constructs a new <code>ParentRunner</code> that will run <code>TestClass</code>.
		 * 
		 * @param klass The test class that is to be executed by the runner.
		 * 
		 * @throws org.flexunit.internals.runners.InitializationError
		 */
		/*
		 * TODO: does it throw an InitializationError?
		*/
		public function ParentRunner( klass:Class ) {
			this._testClass = new TestClass( klass );
			validate();
		}

		/**
		 * Returns a name used to describe this Runner.
		 */
		protected function get name():String {
			return testClass.name;
		}

		/**
		 * Returns a <code>TestClass</code> object wrapping the class to be executed.
		 */
		protected function get testClass():TestClass {
			return _testClass;
		}
		
		/**
		 * Retruns an <code>IDescription</code> of the test class that the runner is running.
		 */
		public function get description():IDescription {
			
			if( !cachedDescription ) {
				//TODO: Have an issue here, this is trying to use a createSuiteDescription which needs metadata
				//this might be an issue here as I am now passing metaDatthrough all of the time.. not sure if anyone was counting on a null
				var description:IDescription = Description.createSuiteDescription( name, testClass.metadata ); //?testClass.metadata[ 0 ]:null );
				var filtered:Array = getFilteredChildren();
				var child:*;
	
				for ( var i:int=0; i<filtered.length; i++ ) {
					child = filtered[ i ];
					description.addChild( describeChild( child ) );
				}
				
				cachedDescription = description;
			}

			return cachedDescription;
		}

		/**
		 * Returns a list of objects that define the children of this Runner.
		 */
		protected function get children():Array {
			return null;
		}
	
		/**
		 * Returns an <code>IDescription</code> for <code>child</code>, which can be assumed to
		 * be an element of the list returned by <code>ParentRunner#children()</code>.
		 * 
		 * @param child The child to describe.
		 * 
		 * @return an <code>IDescription</code> of the provided <code>child</code>.
		 */
		protected function describeChild( child:* ):IDescription {
			return null
		}

		/**
		 * Runs the test corresponding to <code>child</code>, which can be assumed to be
		 * an element of the list returned by <code>ParentRunner#children()</code>.
		 * Subclasses are responsible for making sure that relevant test events are
		 * reported through <code>notifier</code>.
		 * 
		 * @param child The child to run.
		 * @param notifier The <code>IRunNotifier</code> to notify on the progress of the <code>child</code>.
		 * @param childRunnerToken The token used to keep track of the <code>child</code>'s execution.
		 */
		protected function runChild( child:*, notifier:IRunNotifier, childRunnerToken:AsyncTestToken ):void {
		
		}

		/** 
		 * Constructs an <code>IAsyncStatement</code> to run all of the tests in the test class. Override to add pre-/post-processing. 
		 * Here is an outline of the implementation:
		 * 
		 * <ul>
		 * <li>Call <code>#runChild(Object, IRunNotifier, AsyncTestToken)</code> on each object returned by <code> #children()</code> (subject to any imposed filter and sort).</li>
		 * <li>ALWAYS run all non-overridden <code>BeforeClass</code> methods on this class
		 * and superclasses before the previous step; if any throws an
		 * Exception, stop execution and pass the exception on.
		 * <li>ALWAYS run all non-overridden <code>AfterClass</code> methods on this class
		 * and superclasses before any of the previous steps; all AfterClass methods are
		 * always executed: exceptions thrown by previous steps are combined, if
		 * necessary, with exceptions from AfterClass methods into a
		 * <code>MultipleFailureException</code>.
		 * </ul>
		 * 
		 * @param notifier The <code>IRunNotifier</code> to notify on the progress of the children.
		 * 
		 * @return an <code>IAsyncStatement</code>.
		 * 
		 * @see #runChild()
		 */
		protected function classBlock( notifier:IRunNotifier ):IAsyncStatement {
			var sequencer:StatementSequencer = new StatementSequencer();
			
			sequencer.addStep( withBeforeClasses() );
			sequencer.addStep( childrenInvoker( notifier ) );
			sequencer.addStep( withAfterClasses() );
			
			return sequencer;
		}

		/**
		 * Returns an <code>IAsyncStatement</code>: run all non-overridden <code>BeforeClass</code> methods on this class
		 * and superclasses before executing the <code>statement</code>; if any throws an
		 * Exception, stop execution and pass the exception on.
		 * 
		 * @return an <code>IAsyncStatement</code> containing methdos to run before the class.
		 */
		protected function withBeforeClasses():IAsyncStatement {
			var befores:Array = testClass.getMetaDataMethods( "BeforeClass" );
			//Sort the befores array
			befores.sort(compare);
			//this is a deviation from the java approach as we don't have the same type of method information
			var statement:IAsyncStatement = new RunBeforesClass( befores, testClass );
			return statement;
		}

		/**
		 * Returns an <code>IAsyncStatement</code>: run all non-overridden <code>AfterClass</code> methods on this class
		 * and superclasses before executing the <code>statement</code>; all <code>AfterClass</code> methods are
		 * always executed: exceptions thrown by previous steps are combined, if
		 * necessary, with exceptions from <code>AfterClass</code> methods into a
		 * <code>MultipleFailureException</code>.
		 * 
		 * @return an <code>IAsyncStatement</code> containing methods to run after the class.
		 */
		protected function withAfterClasses():IAsyncStatement {
			var afters:Array = testClass.getMetaDataMethods( "AfterClass" );
			//Sort the afters array
			afters.sort(compare);
			var statement:IAsyncStatement = new RunAftersClass( afters, testClass );
			return statement;
		}		
		
		/**
		 * Ensure that no initilization issues are encountered when attempting to setup
		 * the runner for the test class.
		 */
		private function validate():void {
			var errors:Array = new Array();
			collectInitializationErrors(errors);
			if (!(errors.length==0))
				throw new InitializationError(errors);
		}

		/**
		 * Adds to <code>errors</code> an error for each problem noted with the test class 
		 * (available from <code>#testClass()</code>).
		 * Default implementation adds an error for each method annotated with
		 * <code>BeforeClass</code> or <code>AfterClass</code> that is not
		 * <code>public static void</code> with no arguments.
		 * 
		 * @param errors An <code>Array</code> of issues encountered when attempting to setup
		 * the runner for the test class.
		 * 
		 * @see #testClass()
		 */
		protected function collectInitializationErrors( errors:Array ):void {
			validatePublicVoidNoArgMethods( "BeforeClass", true, errors );
			validatePublicVoidNoArgMethods( "AfterClass", true, errors );
		}

		/**
		 * Adds to <code>errors</code> if any method in this class is annotated with
		 * <code>metaDataTag</code>, but:
		 * 
		 * <ul>
		 * <li>is not public, or
		 * <li>takes parameters, or
		 * <li>returns something other than void, or
		 * <li>is static (given <code>isStatic</code> is <code>false</code>), or
		 * <li>is not static (given <code>isStatic</code> is <code>true</code>).</ul>
		 * 
		 * @param metaDataTag The metadata tag used to retrieve the methods.
		 * @param isStatic a Boolean value indicating whether the methods should be static.
		 * @param errors An <code>Array</code> of issues encountered when attempting to setup
		 * the runner for the test class.
		 */
		protected function validatePublicVoidNoArgMethods( metaDataTag:String, isStatic:Boolean, errors:Array ):void {
			var methods:Array = testClass.getMetaDataMethods( metaDataTag  );
	
			var eachTestMethod:FrameworkMethod;
			for ( var i:int=0; i<methods.length; i++ ) {
				eachTestMethod = methods[ i ] as FrameworkMethod;
				eachTestMethod.validatePublicVoidNoArg( isStatic, errors );
			}
		}

		/**
		 * Returns an <code>IAsyncStatement</code>: Call <code>#runChild(Object, IRunNotifier, AsyncTestToken)</code>
		 * on each object returned by <code>#children()</code> (subject to any imposed
		 * filter and sort).
		 * 
		 * @param notifier The <code>IRunNotifier</code> to notify on the progress of the children.
		 * 
		 * @see #runChild()
		 * @see #children()
		 */
		protected function childrenInvoker( notifier:IRunNotifier ):IAsyncStatement {
			var children:Array = getFilteredChildren();

			return new ChildRunnerSequencer( children, runChild, notifier );
		}
		
		/**
		 * Determines if the children have already been filtered and sorted.  If they have, returns the existing
		 * array of filtered and sorted children.  If no array has been genereated, an array is generated by determing
		 * whether each child can run, applies the runner's <code>Filter</code>, applies the runner's
		 * <code>ISorter</code>, and adds it to the array.  This array is then sorted using the runner's <code>ISorter</code>.
		 * 
		 * @return an <code>Array</code> of filtered and sorted children.
		 */
		private function getFilteredChildren():Array {
			if(!childrenFiltered) {
				var filtered:Array = new Array();
				var child:*;
	
				for ( var i:int=0; i<children.length; i++ ) {
					child = children[ i ];
					//Determine if the child matches the filter
					if ( shouldRun( child ) ) {
						try {
							filterChild( child );
							sortChild( child );
							filtered.push( child );
						} catch ( error:Error ) {
							
						}
					}
				}
				
				//Sort all remaining children
				filtered.sort(compare);
				filteredChildren = filtered;
				childrenFiltered = true;
			}
		
			return filteredChildren;
		}
		
		/**
		 * Applies the runner's <code>ISorter</code> to the provided child.
		 * 
		 * @param child The object to which to apply the <code>ISorter</code>.
		 */
		private function sortChild( child:* ):void {
			sorter.apply(child);
		}
		
		/**
		 * This sorting method uses the runner's <code>ISorter</code> to compare two child arguments.
		 */
		//Applies the sorter to an array
		protected function compare(o1:Object, o2:Object):int {
			return sorter.compare(describeChild(o1), describeChild(o2));
		};
		
		/**
		 * Applies the runner's <code>Filter</code> to the provided child.
		 * 
		 * @param child The object to which to apply the <code>Filter</code>.
		 */
		private function filterChild( child:* ):void {
 			if (filterRef != null)
				filterRef.apply(child);
		}

		private var currentEachNotifier:EachTestNotifier;
		/**
		 * Runs the test class and updates the <code>notifier</code> on the status of running the tests.
		 * 
		 * @param notifier The notifier that is notified about issues encountered during the execution of the test class.
		 * @param previousToken The token that is to be notified when the runner has finished execution of the test class.
		 * 
		 * @throws org.flexunit.runner.notification.StoppedByUserException The user has stopped the test run.
		 */
		public function run( notifier:IRunNotifier, previousToken:AsyncTestToken ):void {
			var testNotifier:EachTestNotifier = new EachTestNotifier(notifier, description );
			var resendError:Error;
			
			var token:AsyncTestToken = new AsyncTestToken( ClassNameUtil.getLoggerFriendlyClassName( this ) );
			//Add a reference to the previousToken in this runner's token
			token.previousToken = previousToken;
			token.addNotificationMethod( handleRunnerComplete );
			token[ EACH_NOTIFIER ] = testNotifier;

			try {
				var statement:IAsyncStatement = classBlock( notifier );
				statement.evaluate( token );
			} catch ( error:AssumptionViolatedException ) {
				resendError = error;
				testNotifier.fireTestIgnored();
			} catch ( error:StoppedByUserException ) {
				resendError = error;
				throw error;
			} catch ( error:Error ) {
				resendError = error;
				testNotifier.addFailure( error );
			}
			
			if ( resendError ) {
				previousToken.sendResult( resendError );
			}
		}
		
		/**
		 * Handles the results of the runner on the test class.
		 * 
		 * @param result The results of the running the runner on the test class.
		 */
		private function handleRunnerComplete( result:ChildResult ):void {
			var error:Error = result.error;
			var token:AsyncTestToken = result.token;
			var eachNotifier:EachTestNotifier = result.token[ EACH_NOTIFIER ];
			
			if ( error is AssumptionViolatedException ) {
				eachNotifier.fireTestIgnored();
			} else if ( error is StoppedByUserException ) {
				throw error;
			} else if ( error ) {
				eachNotifier.addFailure( error );
			}
			
			//Notify the token that was passed to the run method that the runner has finished
			token.previousToken.sendResult();
		}
		
		/**
		 * Returns a Boolean value indicating whether the <code>item</code> should run.
		 * 
		 * @param item The item to check to see if it should run.
		 * 
		 * @return a Boolean value indicating whether the <code>item</code> should run .
		 */
		private function shouldRun( item:* ):Boolean {
			return filterRef == null || filterRef.shouldRun( describeChild( item ) );
		}
		
		/**
		 * Applies the provided <code>Filter</code> to the runner.  If every child of the test class is filtered out,
		 * no children will be run, and a <code>NoTestsRemainException</code> will be thrown.
		 * 
		 * @param filter The <code>Filter</code> to apply to the runner.
		 * 
		 * @throws org.flexunit.runner.manipulation.NoTestsRemainException Thrown if all children have been filtered.
		 */
		public function filter( filter:Filter ):void {
			if(filter == this.filterRef)
				return;
			
			this.filterRef = filter;
			childrenFiltered = false;
			
			//Determine if the filter has filtered out every child
			for ( var i:int=0; i<children.length; i++ ) {
				if ( shouldRun( children[ i ] ) ) {
					//We are fine, at least one child has met the filter's criteria
					return;
				}
			}
			
			//All children have been filtered out, there is nothing for the runner to run
			throw new NoTestsRemainException();
		}
		
		/**
		 * Applies the provided <code>ISorter</code> to the runner.
		 * 
		 * @param sorter The <code>ISorter</code> to apply to the runner.
		 */
		public function sort(sorter:ISorter):void {
			//Determine if the runner has already specified a ISorter besides the default META Sorter,
			//if it has, ignore the new ISorter.  This is to prevent a potential problem with a parent Runner
			//overwriting a child's non-default ISorter.
			if(MetadataSorter.META == this.sorter) {
				this.sorter = sorter;
				childrenFiltered = false;
			}
		}
		
		/**
		 * @private
		 * @return
		 */
		public function toString():String {
			return "ParentRunner";
		}
	}
}